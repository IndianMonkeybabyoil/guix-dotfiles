#!/bin/sh
set -e

echo "[+] Cloning Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
fi

echo "[+] Writing zprofile..."
cat <<EOF > ~/.zprofile
source ~/.guix-profile/etc/profile 2>/dev/null || true
source ~/.config/guix/current/etc/profile 2>/dev/null || true
EOF

echo "[+] Writing Guix Home config..."
cat <<EOF > ~/home-configuration.scm
(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu home services desktop)
             (gnu packages)
             (gnu packages admin)
             (gnu packages terminals)
             (gnu packages wm)
             (gnu packages version-control)
             (gnu packages text-editors)
             (gnu packages monitoring)
             (guix gexp))

(home-environment
 (packages
  (list neovim htop btop git rofi-wayland kitty waybar))

 (services
  (list
   (service home-zsh-service-type
            (home-zsh-configuration
             (zshrc
              (plain-file "zshrc"
               "export ZSH=$HOME/.oh-my-zsh
ZSH_THEME=robbyrussell
plugins=(git)

source $ZSH/oh-my-zsh.sh

source ~/.zprofile"))))

   (simple-service
    'env
    home-environment-variables-service-type
    '(("XDG_SESSION_TYPE" . "wayland")
      ("ELECTRON_OZONE_PLATFORM_HINT" . "auto"))))))
EOF

guix home reconfigure ~/home-configuration.scm

echo "[+] Writing Kitty config..."
mkdir -p ~/.config/kitty
cat <<EOF > ~/.config/kitty/kitty.conf
font_family JetBrains Mono
font_size 11.0
background_opacity 0.85
EOF

echo "[+] Writing Hyprland config..."
mkdir -p ~/.config/hypr
cat <<EOF > ~/.config/hypr/hyprland.conf

# Portable GPU setup (works everywhere)
env = XDG_SESSION_TYPE,wayland
env = ELECTRON_OZONE_PLATFORM_HINT,auto

env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct

exec-once = waybar

bind = SUPER, Return, exec, kitty
bind = SUPER, D, exec, rofi -show drun

input {
    kb_layout = us
    follow_mouse = 1
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 10
}
EOF

echo "[+] Setup complete. Start Hyprland with: Hyprland"
