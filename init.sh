set -e

DRIVE="$1"
if [ -z "$DRIVE" ]; then
    echo "Usage: $0 /dev/sdX or /dev/nvme0n1"
    exit 1
fi

# Detect NVMe partition naming early (used throughout)
if echo "$DRIVE" | grep -q "nvme"; then
    PART1="${DRIVE}p1"
    PART2="${DRIVE}p2"
else
    PART1="${DRIVE}1"
    PART2="${DRIVE}2"
fi

echo "[+] Unmounting any existing mounts on /mnt..."
umount -R /mnt 2>/dev/null || true

echo "[+] Wiping old filesystem signatures..."
wipefs -af "$DRIVE"

echo "[+] Partitioning drive..."
sfdisk "$DRIVE" <<EOF
label: gpt
size=1G, type=uefi
type=linux
EOF

# Wait for the kernel to register the new partition table
udevadm settle
sleep 2

echo "[+] Formatting filesystems..."
mkfs.fat -F32 -n EFI "$PART1"
mkfs.ext4 -F -L guix-root "$PART2"

echo "[+] Mounting..."
mount /dev/disk/by-label/guix-root /mnt
mkdir -p /mnt/boot/efi
mount /dev/disk/by-label/EFI /mnt/boot/efi

echo "[+] Starting cow-store..."
herd start cow-store /mnt

echo "[+] Writing Guix channels..."
mkdir -p ~/.config/guix
cat > ~/.config/guix/channels.scm <<'EOF'
(cons* (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29 12AF 6F51 20A0 22FB B48E 1E9F C2C4 CEF6"))))
       %default-channels)
EOF

guix pull

echo "[+] Installing system configuration..."
mkdir -p /mnt/etc/guix
cp ~/.config/guix/channels.scm /mnt/etc/guix/channels.scm

cat > /mnt/etc/config.scm <<'EOF'
(use-modules (gnu)
             (gnu services desktop)
             (gnu services networking)
             (gnu services xorg)
             (gnu packages wm)
             (gnu packages terminals)
             (gnu packages shells)
             (gnu packages linux)
             (gnu packages version-control)
             (nongnu packages linux)
             (nongnu system linux-initrd))

(operating-system
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (list linux-firmware))
 (locale "en_US.utf8")
 (timezone "America/New_York")
 (keyboard-layout (keyboard-layout "us"))

 (bootloader
  (bootloader-configuration
   (bootloader grub-efi-bootloader)
   (targets '("/boot/efi"))
   (keyboard-layout (keyboard-layout "us"))))

 ;; Blacklist nouveau to prevent conflicts with proprietary driver later
 (kernel-arguments
  (append '("modprobe.blacklist=nouveau") %default-kernel-arguments))

 (file-systems
  (cons* (file-system
          (mount-point "/")
          (device (file-system-label "guix-root"))
          (type "ext4"))
         (file-system
          (mount-point "/boot/efi")
          (device (file-system-label "EFI"))
          (type "vfat")
          (flags '(boot)))
         %base-file-systems))

 (users
  (cons (user-account
         (name "goomba")
         (comment "Goomba")
         (group "users")
         (home-directory "/home/goomba")
         (supplementary-groups '("wheel" "netdev" "audio" "video")))
        %base-user-accounts))

 (packages
  (append (list hyprland kitty rofi-wayland git zsh waybar mesa)
          %base-packages))

 (services
  (append
   (list (service network-manager-service-type)
         ;; elogind is already included in %desktop-services;
         ;; adding it separately causes a duplicate service conflict
         (service xorg-server-service-type))
   %desktop-services)))
EOF

guix system init /mnt/etc/config.scm /mnt

echo "[+] Done. Rebooting..."
reboot
