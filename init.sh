#!/bin/sh
set -e

DRIVE=$1

if [ -z "$DRIVE" ]; then
    echo "Usage: $0 /dev/sdX or /dev/nvme0n1"
    exit 1
fi

# Detect partition naming scheme (adds 'p' for nvme)
if echo "$DRIVE" | grep -q "nvme"; then
    PART1="${DRIVE}p1"
    PART2="${DRIVE}p2"
else
    PART1="${DRIVE}1"
    PART2="${DRIVE}2"
fi

# 1. Partition Drive
sfdisk "$DRIVE" <<EOF
label: gpt
size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

# 2. Format Filesystems
mkfs.ext4 -L guix-root "$PART2"
mkfs.fat -F32 -n EFI "$PART1"

# 3. Mount Targets
mount /dev/disk/by-label/guix-root /mnt
mkdir -p /mnt/boot/efi
mount /dev/disk/by-label/EFI /mnt/boot/efi

# 4. Start Cow-Store
herd start cow-store /mnt

# 5. Set up Channels for Installer Environment
mkdir -p ~/.config/guix
cat << 'EOF' > ~/.config/guix/channels.scm
(cons* (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29 12AF 6F51 20A0 22FB"))))
       %default-channels)
EOF

# Update channels
guix pull

# 6. Set up Channels for the Target Rebuilt System
mkdir -p /mnt/etc/guix
cp ~/.config/guix/channels.scm /mnt/etc/guix/channels.scm

mkdir -p /mnt/etc
cat << 'EOF' > /mnt/etc/config.scm
(define-module (system-config)
  #:use-module (gnu)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu system linux-initrd)
  #:use-module (nonguix transformations)
  #:use-module (gnu services desktop)
  #:use-module (gnu services networking)
  #:use-module (gnu services xorg)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages shells)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages version-control))

(use-service-modules desktop networking ssh xorg)

;; Notice the wrapper function encapsulates the operating-system record directly
((nonguix-transformation-nvidia #:driver nvidia-driver #:configure-xorg? #t)
 (operating-system
    (kernel linux)
    (initrd microcode-initrd)
    (firmware (list linux-firmware amdgpu-firmware))
    (locale "en_US.utf8")
    (timezone "America/New_York")
    (keyboard-layout (keyboard-layout "us"))

    (bootloader (bootloader-configuration
                 (bootloader grub-efi-bootloader)
                 (targets '("/boot/efi"))
                 (keyboard-layout keyboard-layout)))

    (kernel-arguments
     (append '("modprobe.blacklist=nouveau")
             %default-kernel-arguments))

    (file-systems (cons* (file-system
                           (mount-point "/")
                           (device (file-system-label "guix-root"))
                           (type "ext4"))
                         (file-system
                           (mount-point "/boot/efi")
                           (device (file-system-label "EFI"))
                           (type "vfat"))
                         %base-file-systems))

    (users (cons (user-account
                  (name "goomba")
                  (comment "Main User")
                  (group "users")
                  (supplementary-groups '("wheel" "netdev" "audio" "video" "input")))
                %base-user-accounts))

    (packages (append (list hyprland kitty rofi-wayland git zsh mesa waybar) %base-packages))

    (services
     (append (list (service screen-locker-service-type)) 
             %desktop-services))))
EOF

# 7. Initialize and Kick-off Installation
guix system init /mnt/etc/config.scm /mnt
reboot
