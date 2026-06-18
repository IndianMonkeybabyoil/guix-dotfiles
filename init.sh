#!/bin/bash
# =============================================================================
# Guix System Installer — nonguix ISO (Patched for Older Stable ISOs)
# Usage: sudo bash 01-install.sh /dev/sdX
# =============================================================================
set -euo pipefail

DRIVE="${1:-}"
if [[ -z "$DRIVE" ]]; then
    echo "Usage: $0 /dev/sdX  OR  $0 /dev/nvme0n1"
    exit 1
fi

if [[ ! -b "$DRIVE" ]]; then
    echo "Error: '$DRIVE' is not a block device."
    exit 1
fi

echo "==> Target drive: $DRIVE"
read -rp "    This will DESTROY all data on $DRIVE. Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

if [[ "$DRIVE" =~ nvme ]]; then
    PART1="${DRIVE}p1"
    PART2="${DRIVE}p2"
else
    PART1="${DRIVE}1"
    PART2="${DRIVE}2"
fi

echo "==> Unmounting any existing mounts under /mnt..."
umount -R /mnt 2>/dev/null || true

echo "==> Wiping filesystem signatures on $DRIVE..."
wipefs -af "$DRIVE"
sgdisk --zap-all "$DRIVE" 2>/dev/null || true
sync

echo "==> Partitioning $DRIVE (GPT: 1 GiB EFI + rest ext4)..."
sgdisk \
    --new=1:0:+1G   --typecode=1:ef00 --change-name=1:"EFI" \
    --new=2:0:0     --typecode=2:8300 --change-name=2:"guix-root" \
    "$DRIVE"

udevadm settle
partprobe "$DRIVE" 2>/dev/null || true
sleep 2

echo "==> Formatting EFI partition ($PART1) as FAT32..."
mkfs.fat -F32 -n EFI "$PART1"

echo "==> Formatting root partition ($PART2) as ext4..."
mkfs.ext4 -F -L guix-root "$PART2"

echo "==> Mounting filesystems..."
mount /dev/disk/by-label/guix-root /mnt
mkdir -p /mnt/boot/efi
mount /dev/disk/by-label/EFI /mnt/boot/efi

echo "==> Starting cow-store on /mnt..."
herd start cow-store /mnt

# Fix SSL Cert bugs inherent to older installation profiles
echo "==> Patching environment SSL certificates..."
guix install nss-certs -p /root/.guix-profile
export SSL_CERT_DIR="/root/.guix-profile/etc/ssl/certs"
export SSL_CERT_FILE="/root/.guix-profile/etc/ssl/certs/ca-certificates.crt"

echo "==> Writing Guix channels (nonguix)..."
mkdir -p /root/.config/guix

cat > /root/.config/guix/channels.scm << 'CHANNELS'
(cons* (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29 12AF 6F51 20A0 22FB B29B 6CDB"))))
       %default-channels)
CHANNELS

echo "==> Authorizing Non-Guix substitute servers..."
wget https://substitutes.nonguix.org/signing-key.pub -O- | sudo guix archive --authorize

echo "==> Pulling channel generations..."
guix pull

echo "==> Writing /mnt/etc/config.scm..."
mkdir -p /mnt/etc/guix
cp /root/.config/guix/channels.scm /mnt/etc/guix/channels.scm

cat > /mnt/etc/config.scm << 'CONFIG'
(use-modules (gnu)
             (gnu services desktop)
             (gnu services networking)
             (gnu packages gl)
             (gnu packages wm)
             (gnu packages terminals)
             (gnu packages shells)
             (gnu packages linux)
             (gnu packages version-control)
             (nongnu packages linux)
             (nongnu packages nvidia)
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

 (kernel-arguments
  (append '("modprobe.blacklist=nouveau"
            "nvidia-drm.modeset=1"
            "quiet")
          %default-kernel-arguments))

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

 (users (cons (user-account
               (name "goomba")
               (comment "Primary User")
               (group "users")
               (supplementary-groups '("wheel" "netdev" "audio" "video")))
              %base-user-accounts))

 (packages
  (append (list git mesa nvidia-driver nvidia-libs)
          %base-packages))

 (services
  (append
   (list
    (service network-manager-service-type)
    (service wpa-supplicant-service-type)
    (service elogind-service-type)
    (service seatd-service-type))

   (modify-services %desktop-services
     (delete gdm-service-type)))))
CONFIG

echo "==> Building and initializing system profile..."
guix system init /mnt/etc/config.scm /mnt

echo "==> Installation complete! Rebooting..."
reboot
