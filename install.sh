#!/bin/bash
# Minimal Daily‑Driver Install Script – ThinkPad T480 – Hyprland Edition
# ---------------------------------------------------------------------
# Installs a Wayland/Hyprland desktop, pulls your dotfiles, and applies
# workstation tweaks. Run as your regular user (sudo is invoked where
# root privileges are required).

set -euo pipefail

################################
#  USER‑TUNABLE CONFIGURATION  #
################################

# --- Git repositories ---
DOTFILES_REPO_URL="https://github.com/ripwoozy/dotfiles.git"
DOTFILES_REPO_BRANCH="main"
YAY_REPO_URL="https://aur.archlinux.org/yay.git"

# --- XDG locations ---
CONFIG_DIR="$HOME/.config"
LOCAL_BIN_DIR="$HOME/.local/bin"

REPO_PKGS=(
  # CLI / essentials
  kitty fastfetch python-pywal bat
  playerctl libnotify imv mpv wget zsh
  awww unzip rofi ttf-jetbrains-mono waybar
  ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts-emoji gnome-themes-extra
  spotify-launcher wl-clipboard grim mako jq nemo

  # Audio (PipeWire)
  alsa-utils pipewire pipewire-alsa
  pipewire-pulse wireplumber cava

  # Bluetooth & networking
  bluez bluez-utils bluetui networkmanager

  # Power / misc system libs
  libgtop tlp powertop
  btop brightnessctl nvtop timeshift

  # Build base
  base-devel git

  # Wayland
  hyprland
  hypridle
  hyprlock
  xdg-desktop-portal-hyprland
  xdg-desktop-portal

  # Optional
  qemu-desktop
  virt-manager
  dnsmasq
  libvirt
  obsidian
)

AUR_PKGS=(
  "visual-studio-code-bin"
  "waypaper"
  "python-pywalfox"
  "librewolf-bin"
  "spicetify-cli"
  "wpgtk-git"
)

################################
#  TERMINAL COLOR HELPERS      #
################################
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
msg()  { printf "%b\n" "${BLUE}[ $* ]${NC}"; }
ok()   { printf "%b\n" "${GREEN}$*${NC}"; }
err()  { printf "%b\n" "${RED}$*${NC}" >&2; }
die()  { err "Error: $*"; exit 1; }
trap 'die "Unexpected error on line $LINENO"' ERR

################################
#  HELPER FUNCTIONS            #
################################
make_dirs() {
  msg "Creating XDG user dirs"
  for d in Documents Downloads Music Pictures Videos; do
    mkdir -p "$HOME/$d"
  done
}

install_yay() {
  msg "Installing yay (AUR helper)"
  if ! command -v yay &>/dev/null; then
    git clone "$YAY_REPO_URL" "$HOME/yay"
    (cd "$HOME/yay" && makepkg -si --noconfirm)
  else
    ok "yay already present – skipping"
  fi
}

pac_install() { sudo pacman -S --needed --noconfirm "$@"; }
yay_install() { yay -S --needed --noconfirm "$@"; }

install_packages() {
  msg "Installing official repo packages"
  pac_install "${REPO_PKGS[@]}"

  msg "Installing AUR packages"
  yay_install "${AUR_PKGS[@]}"
}

clone_dotfiles() {
  msg "Cloning dotfiles"
  git clone -b "$DOTFILES_REPO_BRANCH" "$DOTFILES_REPO_URL" "$HOME/.dotfiles"
}

deploy_configs() {
  msg "Deploying configuration directories"
  mkdir -p "$CONFIG_DIR"
  for dir in "$HOME/.dotfiles"/*/; do
    cfg="$(basename "$dir")"
    mkdir -p "$CONFIG_DIR/$cfg"
    cp -rT "$dir" "$CONFIG_DIR/$cfg"
  done
  chmod -R +x "$CONFIG_DIR/polybar/scripts" &>/dev/null || true
  chmod -R +x "$CONFIG_DIR/hypr/scripts" &>/dev/null || true
}

setup_local_bin() {
  msg "Copying user scripts into $LOCAL_BIN_DIR"
  mkdir -p "$LOCAL_BIN_DIR"
  cp -r "$HOME/.dotfiles/local/bin/"* "$LOCAL_BIN_DIR/"
  chmod +x "$LOCAL_BIN_DIR/"*
}

setup_wallpaper() {
  msg "Copying wallpapers and setting default"
  wall_dir="$HOME/Pictures/Wallpapers"
  mkdir -p "$wall_dir"
  cp -r "$HOME/.dotfiles/wallpapers/"* "$wall_dir/"
  wal -i "$wall_dir/riversunset.png" &>/dev/null
}

setup_wpgtk() {
  msg "Configuring wpgtk (if installed)"

  if command -v wpg-install.sh &>/dev/null; then
    /usr/bin/wpg-install.sh -G -i
    ok "wpgtk configured successfully"
  else
    err "wpgtk not found – skipping configuration"
  fi
}

setup_zsh() {
  msg "Installing Oh‑My‑Zsh + plugins"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
  cp "$HOME/.dotfiles/zshrc" "$HOME/.zshrc"
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting; do
    dst="$ZSH_CUSTOM/plugins/$(basename "$repo")"
    [ -d "$dst" ] || git clone "https://github.com/$repo.git" "$dst"
  done
}

#change_default_shell() {
#  if [[ "${SHELL##*/}" == "zsh" ]]; then
#    ok "Default shell already set to zsh"
#    return
#  fi

#  read -rp "Set zsh as your default shell? [y/N] " confirm
#  [[ "$confirm" =~ ^[Yy]$ ]] || return

#  zsh_path="$(command -v zsh)"
#  [[ -n "$zsh_path" ]] || die "zsh is not installed"

#  if command -v chsh &>/dev/null && chsh -s "$zsh_path" "$USER" 2>/dev/null; then
#    ok "Default shell changed to zsh"
#    return
#  fi

#  sudo usermod --shell "$zsh_path" "$USER"
#  ok "Default shell changed to zsh"
#}

enable_services() {
  msg "Enabling system & user services"
  systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true
  sudo systemctl enable --now bluetooth NetworkManager upower tlp libvirtd 2>/dev/null || true
  sudo usermod -aG libvirt "$USER"
}

cleanup() { rm -rf "$HOME/yay" "$HOME/.dotfiles"; }

################################
#              MAIN            #
################################
main() {
  make_dirs
  install_yay
  install_packages
  clone_dotfiles
  deploy_configs
  setup_local_bin
  setup_wallpaper
  setup_wpgtk
  setup_zsh
  # change_default_shell
  enable_services
  ok "Installation complete! Reboot and launch Hyprland via your display manager or by running \e[1mHyprland\e[0m from a TTY."
  cleanup
}

################################
#         ASCII HEADER         #
################################
printf "${GREEN}"
cat << 'EOF'
██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
                https://github.com/ripwoozy/
EOF
printf "${NC}\n\n"

main "$@"
