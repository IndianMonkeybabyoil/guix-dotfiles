#!/bin/bash
# =============================================================================
# Guix Home + Dotfiles Setup — run as 'goomba' after first boot
# =============================================================================
set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
    echo "Error: Run this script as the regular user (goomba), not root."
    exit 1
fi

echo "==> Setting up local user SSL certificates..."
guix install nss-certs -p "$HOME/.guix-profile"
export SSL_CERT_DIR="$HOME/.guix-profile/etc/ssl/certs"
export SSL_CERT_FILE="$HOME/.guix-profile/etc/ssl/certs/ca-certificates.crt"

echo "==> Syncing system-wide channels to user profile..."
mkdir -p "$HOME/.config/guix"
sudo cp /etc/guix/channels.scm "$HOME/.config/guix/channels.scm" || true
sudo chown goomba:users "$HOME/.config/guix/channels.scm" || true

echo "==> Running initial user guix pull..."
guix pull

echo "==> Installing Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no \
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

echo "==> Writing ~/.zprofile..."
cat > "$HOME/.zprofile" << 'ZPROFILE'
if [ -f "$HOME/.guix-profile/etc/profile" ]; then
    source "$HOME/.guix-profile/etc/profile"
fi
if [ -f "$HOME/.config/guix/current/etc/profile" ]; then
    source "$HOME/.config/guix/current/etc/profile"
fi
ZPROFILE

echo "==> Writing ~/home-configuration.scm..."
cat > "$HOME/home-configuration.scm" << 'HOME_CONFIG'
(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
             (gnu home services environment-variables)
             (gnu packages)
             (gnu packages admin)
             (gnu packages terminals)
             (gnu packages wm)
             (gnu packages text-editors)
             (gnu packages monitoring)
             (gnu packages version-control)
             (guix gexp))

(home-environment
 (packages
  (list neovim htop btop git rofi-wayland kitty waybar zsh))

 (services
  (list
   (service home-zsh-service-type
            (home-zsh-configuration
             (zshrc
              (list
               (plain-file "zshrc" "\
export ZSH=\"$HOME/.oh-my-zsh\"
ZSH_THEME=\"robbyrussell\"
plugins=(git)
source \"$ZSH/oh-my-zsh.sh\"
[ -f ~/.zprofile ] && source ~/.zprofile
")))))

   (simple-service
    'wayland-env
    home-environment-variables-service-type
    '(("XDG_SESSION_TYPE"           . "wayland")
      ("XDG_CURRENT_DESKTOP"         . "Hyprland")
      ("ELECTRON_OZONE_PLATFORM_HINT" . "auto")
      ("MOZ_ENABLE_WAYLAND"          . "1")
      ("QT_QPA_PLATFORM"             . "wayland")
      ("SDL_VIDEODRIVER"             . "wayland"))))))
HOME_CONFIG

echo "==> Running guix home reconfigure..."
guix home reconfigure "$HOME/home-configuration.scm"

echo "==> Writing config configurations..."
mkdir -p "$HOME/.config/kitty" "$HOME/.config/hypr" "$HOME/.config/waybar"

cat > "$HOME/.config/kitty/kitty.conf" << 'KITTY'
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        11.0
background_opacity 0.90
cursor_shape        beam
cursor_blink_interval 0.5
window_padding_width 8
confirm_os_window_close 0
scrollback_lines 10000
repaint_delay 10
sync_to_monitor yes
KITTY

cat > "$HOME/.config/hypr/hyprland.conf" << 'HYPR'
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = MOZ_ENABLE_WAYLAND,1
env = QT_QPA_PLATFORM,wayland

# NVIDIA hardware configurations
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct

exec-once = waybar
exec-once = dunst
monitor = ,preferred,auto,1

input {
    kb_layout  = us
    follow_mouse = 1
    sensitivity  = 0.0
    touchpad { natural_scroll = true }
}

general {
    gaps_in      = 5
    gaps_out     = 10
    border_size  = 2
    col.active_border   = rgba(cba6f7ff) rgba(89b4faff) 45deg
    col.inactive_border = rgba(45475aff)
    layout       = dwindle
    allow_tearing = false
}

decoration {
    rounding = 10
    blur { enabled = true size = 5 passes = 2 }
    drop_shadow      = true
    shadow_range     = 8
    shadow_render_power = 3
    col.shadow       = rgba(1a1a1aee)
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows,     1, 7, myBezier
    animation = windowsOut,  1, 7, default, popin 80%
    animation = border,      1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade,        1, 7, default
    animation = workspaces,  1, 6, default
}

dwindle { pseudotile = true preserve_split = true }
misc { force_default_wallpaper = 0 disable_hyprland_logo = true }

$mod = SUPER
bind = $mod, Return,    exec, kitty
bind = $mod, D,         exec, rofi -show drun
bind = $mod, Q,         killactive
bind = $mod, M,         exit
bind = $mod, V,         togglefloating
bind = $mod, F,         fullscreen

bind = $mod, h, movefocus, l
bind = $mod, l, movefocus, r
bind = $mod, k, movefocus, u
bind = $mod, j, movefocus, d

bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9
bind = $mod, 0, workspace, 10

bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9
bind = $mod SHIFT, 0, movetoworkspace, 10

bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow
HYPR

cat > "$HOME/.config/waybar/config" << 'WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left":   ["hyprland/workspaces"],
    "modules-center": ["hyprland/window"],
    "modules-right":  ["network", "pulseaudio", "cpu", "memory", "clock", "tray"],
    "hyprland/workspaces": { "format": "{id}" },
    "clock": { "format": "{:%a %b %d  %H:%M}" },
    "cpu": { "format": "CPU {usage}%", "interval": 5 },
    "memory": { "format": "MEM {}%", "interval": 5 },
    "network": {
        "format-wifi": "{essid} ({signalStrength}%)",
        "format-ethernet": "{ifname}",
        "format-disconnected": "Disconnected"
    },
    "pulseaudio": { "format": "VOL {volume}%" },
    "tray": { "spacing": 8 }
}
WAYBAR

echo "==> Changing shell target configuration..."
ZSH_PATH="/run/current-system/profile/bin/zsh"
if [ -f "$ZSH_PATH" ] || which zsh &>/dev/null; then
    sudo chsh -s "$(which zsh)" goomba
fi

echo "==> Setup Complete! Type 'Hyprland' to run your desktop env."
