#!/bin/sh
set -e

# 1. Clone Oh My Zsh FIRST so files exist when configuration initializes
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh
fi

# 2. Write the declarative profile configuration
cat << 'EOF' > ~/.zprofile
if [ -f ~/.guix-profile/etc/profile ]; then
  . ~/.guix-profile/etc/profile
fi

if [ -f ~/.config/guix/current/etc/profile ]; then
  . ~/.config/guix/current/etc/profile
fi
EOF

# 3. Create Home Configuration file
cat << 'EOF' > ~/home-configuration.scm
(define-module (home-config)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages text-editors)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages version-control))

(home-environment
 (packages
  (list neovim
        htop
        rofi-wayland
        git
        btop))

 (services
  (list
   (service home-zsh-service-type
            (home-zsh-configuration
             (zshrc (list (plain-file "zshrc" "
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME=\"robbyrussell\"
plugins=(git)

if [ -f $ZSH/oh-my-zsh.sh ]; then
  source $ZSH/oh-my-zsh.sh
fi

if [ -f ~/.zprofile ]; then
  source ~/.zprofile
fi
")))))

   (service home-environment-variables-service-type
            '(("XDG_SESSION_TYPE" . "wayland")
              ("ELECTRON_OZONE_PLATFORM_HINT" . "auto"))))))
EOF

# 4. Initialize user space configuration via Guix Home
guix home reconfigure ~/home-configuration.scm

# 5. Populate Wayland/Hyprland configuration directories
mkdir -p ~/.config/kitty
cat << 'EOF' > ~/.config/kitty/kitty.conf
font_family      JetBrains Mono
font_size        11.0
background_opacity 0.85
confirm_os_window_close 0
enable_audio_bell no
EOF

mkdir -p ~/.config/hypr
cat << 'EOF' > ~/.config/hypr/hyprland.conf
exec-once = lspci | grep -qi nvidia && hyprctl setenv LIBVA_DRIVER_NAME nvidia
exec-once = lspci | grep -qi nvidia && hyprctl setenv GBM_BACKEND nvidia-drm
exec-once = lspci | grep -qi nvidia && hyprctl setenv __GLX_VENDOR_LIBRARY_NAME nvidia
exec-once = waybar

env = XDG_SESSION_TYPE,wayland
env = ELECTRON_OZONE_PLATFORM_HINT,auto

cursor {
    no_hardware_cursors = true
}

bind = SUPER, Return, exec, kitty
bind = SUPER, D, exec, rofi -show drun

monitor=,preferred,auto,1

input {
    kb_layout = us
    follow_mouse = 1

    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
}

bind = SUPER, C, killactive
bind = SUPER, M, exit
bind = SUPER, V, togglefloating
bind = SUPER, F, fullscreen

bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4

bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
EOF
