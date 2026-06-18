#!/bin/bash
# =============================================================================
# Guix System Installer — nonguix ISO
# Usage: sudo bash 01-install.sh /dev/sdX
#        sudo bash 01-install.sh /dev/nvme0n1
# =============================================================================
set -euo pipefail

# ── Argument check ────────────────────────────────────────────────────────────
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

# ── Partition naming (NVMe vs SATA/USB) ──────────────────────────────────────
if [[ "$DRIVE" =~ nvme ]]; then
    PART1="${DRIVE}p1"
    PART2="${DRIVE}p2"
else
    PART1="${DRIVE}1"
    PART2="${DRIVE}2"
fi

# ── Unmount / wipe ────────────────────────────────────────────────────────────
echo "==> Unmounting any existing mounts under /mnt..."
umount -R /mnt 2>/dev/null || true

echo "==> Wiping filesystem signatures on $DRIVE..."
wipefs -af "$DRIVE"
sgdisk --zap-all "$DRIVE" 2>/dev/null || true
sync

# ── Partition ─────────────────────────────────────────────────────────────────
echo "==> Partitioning $DRIVE (GPT: 1 GiB EFI + rest ext4)..."
sgdisk \
    --new=1:0:+1G   --typecode=1:ef00 --change-name=1:"EFI" \
    --new=2:0:0     --typecode=2:8300 --change-name=2:"guix-root" \
    "$DRIVE"

# Give the kernel a moment to re-read the partition table
udevadm settle
partprobe "$DRIVE" 2>/dev/null || true
sleep 2

# ── Format ────────────────────────────────────────────────────────────────────
echo "==> Formatting EFI partition ($PART1) as FAT32..."
mkfs.fat -F32 -n EFI "$PART1"

echo "==> Formatting root partition ($PART2) as ext4..."
mkfs.ext4 -F -L guix-root "$PART2"

# ── Mount ─────────────────────────────────────────────────────────────────────
echo "==> Mounting filesystems..."
mount /dev/disk/by-label/guix-root /mnt
mkdir -p /mnt/boot/efi
mount /dev/disk/by-label/EFI /mnt/boot/efi

# ── cow-store (must point at /mnt so the store is written to the target) ──────
echo "==> Starting cow-store on /mnt..."
herd start cow-store /mnt

# ── Guix channels ─────────────────────────────────────────────────────────────
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

echo "==> Running guix pull (this will take a while)..."
guix pull

# ── System configuration ──────────────────────────────────────────────────────
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
             (nongnu system linux-initrd))

(operating-system
 ;; --- Kernel & firmware (nonguix) ---
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (list linux-firmware))

 ;; --- Locale / time / keyboard ---
 (locale "en_US.utf8")
 (timezone "America/New_York")
 (keyboard-layout (keyboard-layout "us"))

 ;; --- Bootloader ---
 (bootloader
  (bootloader-configuration
   (bootloader grub-efi-bootloader)
   (targets '("/boot/efi"))
   (keyboard-layout (keyboard-layout "us"))))

 ;; --- Kernel arguments ---
 ;; Blacklist nouveau so the proprietary driver (installed later) can load.
 (kernel-arguments
  (append '("modprobe.blacklist=nouveau"
            "quiet")
          %default-kernel-arguments))

 ;; --- Filesystems ---
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

 ;; --- Users ---
 (users
  (cons (user-account
         (name "goomba")
         (comment "Goomba")
         (group "users")
         (home-directory "/home/goomba")
         (supplementary-groups
          '("wheel" "netdev" "audio" "video" "input" "seat")))
        %base-user-accounts))

 ;; --- Base packages (system-level) ---
 ;; Keep this minimal; user packages go in Guix Home later.
 (packages
  (append (list git mesa)
          %base-packages))

 ;; --- Services ---
 (services
  (append
   (list
    ;; Networking
    (service network-manager-service-type)
    (service wpa-supplicant-service-type)

    ;; Seat / session management (required for Wayland / Hyprland)
    (service elogind-service-type)
    (service seatd-service-type))

   ;; %desktop-services already includes dbus, udev, polkit, etc.
   ;; Remove the default GDM so we can start Hyprland manually.
   (modify-services %desktop-services
     (delete gdm-service-type)))))
CONFIG

# ── Install ────────────────────────────────────────────────────────────────────
echo "==> Running guix system init — this is the long part..."
guix system init /mnt/etc/config.scm /mnt

echo ""
echo "==> Installation complete!"
echo "    Remove the USB drive and reboot, then log in as root"
echo "    and run 02-home-setup.sh as the 'goomba' user."
echo ""
reboot
