set -e

echo "[+] Cloning Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
fi

echo "[+] Writing zprofile..."
cat > ~/.zprofile <<'EOF'
# Load the system-wide Guix profile
[ -f "$HOME/.guix-profile/etc/profile" ] && source "$HOME/.guix-profile/etc/profile"
# Load the per-user guix pull profile
[ -f "$HOME/.config/guix/current/etc/profile" ] && source "$HOME/.config/guix/current/etc/profile"
EOF

echo "[+] Writing Guix Home config..."
cat > ~/home-configuration.scm <<'EOF'
(use-modules (gnu home)
             (gnu home services)
             (gnu home services shells)
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
              (list (plain-file "zshrc"
                     "export ZSH=$HOME/.oh-my-zsh
ZSH_THEME=robbyrussell
plugins=(git)
source $ZSH/oh-my-zsh.sh
[ -f ~/.zprofile ] && source ~/.zprofile")))))
   (simple-service
    'env-vars
    home-environment-variables-service-type
    '(("XDG_SESSION_TYPE" . "wayland")
      ("ELECTRON_OZONE_PLATFORM_HINT" . "auto"))))))
EOF

guix home reconfigure ~/home-configuration.scm

echo "[+] Writing Kitty config..."
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf <<'EOF'
font_family JetBrains Mono
font_size 11.0
background_opacity 0.85
enable_audio_bell no
EOF

echo "[+] Writing Hyprland config..."
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf <<'EOF'
# Wayland / Nvidia environment variables
# Remove the nvidia-specific lines if you're not on Nvidia
env = XDG_SESSION_TYPE,wayland
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct

exec-once = waybar

# Key bindings
bind = SUPER, Return, exec, kitty
bind = SUPER, D, exec, rofi -show drun
bind = SUPER, Q, killactive
bind = SUPER SHIFT, E, exit

input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
    col.active_border = rgba(cba6f7ff)
    col.inactive_border = rgba(45475aff)
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 5
        passes = 2
    }
}

dwindle {
    pseudotile = false
    preserve_split = true
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Workspaces 1-9
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
EOF

echo "[+] Setup complete. Start Hyprland with: Hyprland"
