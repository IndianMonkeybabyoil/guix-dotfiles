#!/bin/bash
# =============================================================================
# Guix Home + Dotfiles Setup — run as 'goomba' after first boot
# Usage: bash 02-home-setup.sh
# =============================================================================
set -euo pipefail

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ "$(id -u)" -eq 0 ]]; then
    echo "Error: Run this script as the regular user (goomba), not root."
    exit 1
fi

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
echo "==> Installing Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no \
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

# ── Guix profile sourcing ─────────────────────────────────────────────────────
echo "==> Writing ~/.zprofile..."
cat > "$HOME/.zprofile" << 'ZPROFILE'
# Source Guix profiles so that installed packages are on PATH
if [ -f "$HOME/.guix-profile/etc/profile" ]; then
    source "$HOME/.guix-profile/etc/profile"
fi
if [ -f "$HOME/.config/guix/current/etc/profile" ]; then
    source "$HOME/.config/guix/current/etc/profile"
fi
ZPROFILE

# ── Guix Home configuration ───────────────────────────────────────────────────
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

 ;; --- User packages ---
 (packages
  (list neovim
        htop
        btop
        git
        rofi-wayland
        kitty
        waybar))

 ;; --- Services ---
 (services
  (list
   ;; Zsh with Oh My Zsh
   (service home-zsh-service-type
            (home-zsh-configuration
             (zshrc
              (list
               (plain-file "zshrc" "\
export ZSH=\"$HOME/.oh-my-zsh\"
ZSH_THEME=\"robbyrussell\"
plugins=(git)
source \"$ZSH/oh-my-zsh.sh\"
# Source Guix profiles
[ -f ~/.zprofile ] && source ~/.zprofile
")))))

   ;; Wayland environment variables
   (simple-service
    'wayland-env
    home-environment-variables-service-type
    '(("XDG_SESSION_TYPE"            . "wayland")
      ("XDG_CURRENT_DESKTOP"         . "Hyprland")
      ("ELECTRON_OZONE_PLATFORM_HINT" . "auto")
      ("MOZ_ENABLE_WAYLAND"          . "1")
      ("QT_QPA_PLATFORM"             . "wayland")
      ("SDL_VIDEODRIVER"             . "wayland"))))))
HOME_CONFIG

echo "==> Running guix home reconfigure..."
guix home reconfigure "$HOME/home-configuration.scm"

# ── Kitty ─────────────────────────────────────────────────────────────────────
echo "==> Writing ~/.config/kitty/kitty.conf..."
mkdir -p "$HOME/.config/kitty"
cat > "$HOME/.config/kitty/kitty.conf" << 'KITTY'
# --- Font ---
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        11.0

# --- Appearance ---
background_opacity 0.90
cursor_shape       beam
cursor_blink_interval 0.5

# --- Window ---
window_padding_width 8
confirm_os_window_close 0

# --- Scrollback ---
scrollback_lines 10000

# --- Performance ---
repaint_delay 10
sync_to_monitor yes
KITTY

# ── Hyprland ──────────────────────────────────────────────────────────────────
echo "==> Writing ~/.config/hypr/hyprland.conf..."
mkdir -p "$HOME/.config/hypr"
cat > "$HOME/.config/hypr/hyprland.conf" << 'HYPR'
# =============================================================================
# Hyprland configuration
# GPU note: nvidia env vars are commented out by default.
# Uncomment the nvidia block if you have installed the proprietary driver.
# =============================================================================

# --- Wayland / general env ---
env = XDG_SESSION_TYPE,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = MOZ_ENABLE_WAYLAND,1
env = QT_QPA_PLATFORM,wayland

# --- Nvidia (uncomment after installing nvidia driver via Guix) ---
# env = LIBVA_DRIVER_NAME,nvidia
# env = GBM_BACKEND,nvidia-drm
# env = __GLX_VENDOR_LIBRARY_NAME,nvidia
# env = NVD_BACKEND,direct
# env = WLR_NO_HARDWARE_CURSORS,1

# --- Autostart ---
exec-once = waybar
exec-once = dunst

# --- Monitor (auto-detect; change if needed) ---
monitor = ,preferred,auto,1

# --- Input ---
input {
    kb_layout  = us
    follow_mouse = 1
    sensitivity  = 0.0

    touchpad {
        natural_scroll = true
    }
}

# --- General ---
general {
    gaps_in      = 5
    gaps_out     = 10
    border_size  = 2
    col.active_border   = rgba(cba6f7ff) rgba(89b4faff) 45deg
    col.inactive_border = rgba(45475aff)
    layout       = dwindle
    allow_tearing = false
}

# --- Decoration ---
decoration {
    rounding = 10

    blur {
        enabled = true
        size    = 5
        passes  = 2
    }

    drop_shadow      = true
    shadow_range     = 8
    shadow_render_power = 3
    col.shadow       = rgba(1a1a1aee)
}

# --- Animations ---
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

# --- Layouts ---
dwindle {
    pseudotile     = true
    preserve_split = true
}

master {
    new_is_master = true
}

# --- Miscellaneous ---
misc {
    force_default_wallpaper = 0
    disable_hyprland_logo   = true
}

# =============================================================================
# Keybindings
# =============================================================================
$mod = SUPER

bind = $mod, Return,    exec, kitty
bind = $mod, D,         exec, rofi -show drun
bind = $mod, Q,         killactive
bind = $mod, M,         exit
bind = $mod, V,         togglefloating
bind = $mod, F,         fullscreen

# --- Focus ---
bind = $mod, h, movefocus, l
bind = $mod, l, movefocus, r
bind = $mod, k, movefocus, u
bind = $mod, j, movefocus, d

# --- Move windows ---
bind = $mod SHIFT, h, movewindow, l
bind = $mod SHIFT, l, movewindow, r
bind = $mod SHIFT, k, movewindow, u
bind = $mod SHIFT, j, movewindow, d

# --- Workspaces ---
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

# --- Mouse window controls ---
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow
HYPR

# ── Waybar ────────────────────────────────────────────────────────────────────
echo "==> Writing minimal ~/.config/waybar/config..."
mkdir -p "$HOME/.config/waybar"
cat > "$HOME/.config/waybar/config" << 'WAYBAR'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left":   ["hyprland/workspaces"],
    "modules-center": ["hyprland/window"],
    "modules-right":  ["network", "pulseaudio", "cpu", "memory", "clock", "tray"],

    "hyprland/workspaces": {
        "format": "{id}"
    },
    "clock": {
        "format": "{:%a %b %d  %H:%M}",
        "tooltip-format": "<tt>{calendar}</tt>"
    },
    "cpu": {
        "format": "CPU {usage}%",
        "interval": 5
    },
    "memory": {
        "format": "MEM {}%",
        "interval": 5
    },
    "network": {
        "format-wifi":         "{essid} ({signalStrength}%)",
        "format-ethernet":     "{ifname}",
        "format-disconnected": "Disconnected",
        "tooltip-format":      "{ipaddr}"
    },
    "pulseaudio": {
        "format":        "VOL {volume}%",
        "format-muted":  "MUTED",
        "on-click":      "pavucontrol"
    },
    "tray": {
        "spacing": 8
    }
}
WAYBAR

# ── Change default shell to Zsh ───────────────────────────────────────────────
echo "==> Setting default shell to zsh..."
ZSH_PATH="$(which zsh 2>/dev/null || true)"
if [[ -n "$ZSH_PATH" ]]; then
    # In Guix, chsh targets /etc/passwd — use sudo if needed
    if sudo chsh -s "$ZSH_PATH" "$(whoami)" 2>/dev/null; then
        echo "    Shell changed to $ZSH_PATH"
    else
        echo "    Note: Could not run chsh. Run manually: sudo chsh -s $ZSH_PATH $(whoami)"
    fi
else
    echo "    Note: zsh not found on PATH yet. It will be available after guix home activates."
fi

echo ""
echo "==> Setup complete!"
echo ""
echo "    Next steps:"
echo "      1. Log out and back in (or reboot) to activate the new shell."
echo "      2. Start Hyprland:  Hyprland"
echo "      3. If you have an NVIDIA GPU, uncomment the nvidia env block in:"
echo "         ~/.config/hypr/hyprland.conf"
echo "         and install the driver:  guix install nvidia-driver  (nonguix)"
echo ""
