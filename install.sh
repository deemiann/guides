#!/usr/bin/env bash

set -e

# ============================================================
# Dotfiles + paquetes + configuración del sistema
# Para Arch Linux
# ============================================================

DOTFILES_REPO="https://github.com/deemiann/dotfiles-arch.git"
CFG_DIR="$HOME/.cfg"
BACKUP_DIR="$HOME/.config-backup"

echo "=============================================="
echo " Instalación de dotfiles - Arch Linux"
echo "=============================================="

# ------------------------------------------------------------
# 1. Comprobar que se ejecuta como usuario normal
# ------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    echo "No ejecutes este script como root."
    exit 1
fi

# ------------------------------------------------------------
# 2. Instalar Git si no está instalado
# ------------------------------------------------------------

if ! command -v git &>/dev/null; then
    echo "[+] Instalando git..."
    sudo pacman -S --needed --noconfirm git
fi

# ------------------------------------------------------------
# 3. Crear .gitignore
# ------------------------------------------------------------

echo "[+] Configurando .gitignore..."

touch "$HOME/.gitignore"

if ! grep -qxF ".cfg" "$HOME/.gitignore"; then
    echo ".cfg" >> "$HOME/.gitignore"
fi

# ------------------------------------------------------------
# 4. Clonar repositorio bare
# ------------------------------------------------------------

if [[ ! -d "$CFG_DIR" ]]; then
    echo "[+] Clonando dotfiles..."
    git clone --bare "$DOTFILES_REPO" "$CFG_DIR"
else
    echo "[!] $CFG_DIR ya existe."
fi

# ------------------------------------------------------------
# 5. Función para trabajar con el repositorio bare
# ------------------------------------------------------------

config() {
    /usr/bin/git --git-dir="$CFG_DIR" --work-tree="$HOME" "$@"
}

# ------------------------------------------------------------
# 7. Checkout de los dotfiles
# ------------------------------------------------------------

echo "[+] Aplicando dotfiles..."

config checkout -f

# ------------------------------------------------------------
# 8. Configuración del repositorio bare
# ------------------------------------------------------------

echo "[+] Configurando status.showUntrackedFiles..."

config config --local status.showUntrackedFiles no

# ------------------------------------------------------------
# 9. Instalar paquetes de pkglist.txt
# ------------------------------------------------------------

PKGLIST="$HOME/.config/system-backup/pkglist.txt"

if [[ -f "$PKGLIST" ]]; then

    echo
    echo "=============================================="
    echo " Instalando paquetes de pkglist.txt"
    echo "=============================================="

    sudo pacman -Syu --needed --noconfirm

    sudo pacman -S --needed --noconfirm - < "$PKGLIST"

else
    echo "[!] No se encontró:"
    echo "    $PKGLIST"
fi

# ------------------------------------------------------------
# 10. Instalar yay
# ------------------------------------------------------------

if ! command -v yay &>/dev/null; then

    echo
    echo "=============================================="
    echo " Instalando yay"
    echo "=============================================="

    TMP_DIR=$(mktemp -d)

    git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"

    cd "$TMP_DIR/yay"

    makepkg -si --noconfirm

    cd "$HOME"

    rm -rf "$TMP_DIR"

else
    echo "[+] yay ya está instalado."
fi

# ------------------------------------------------------------
# 11. Instalar Brave
# ------------------------------------------------------------

echo
echo "[+] Instalando Brave..."

yay -S --needed --noconfirm brave-bin

# ------------------------------------------------------------
# 13. Instalar configuración Xorg
# ------------------------------------------------------------

XORG_SOURCE="$HOME/.config/system-backup/xorg"
XORG_DEST="/etc/X11/xorg.conf.d"

if [[ -d "$XORG_SOURCE" ]]; then

    echo
    echo "[+] Instalando configuración de Xorg..."

    sudo mkdir -p "$XORG_DEST"

    for file in "$XORG_SOURCE"/*.conf; do

        [[ -e "$file" ]] || continue

        echo "    Copiando $(basename "$file")"

        sudo cp "$file" "$XORG_DEST/"

    done

else
    echo "[!] No se encontró:"
    echo "    $XORG_SOURCE"
fi

# ------------------------------------------------------------
# 15. Instalar zram-generator
# ------------------------------------------------------------

ZRAM_SOURCE="$HOME/.config/system-backup/zram-generator.conf"
ZRAM_DEST="/etc/systemd/zram-generator.conf"

if [[ -f "$ZRAM_SOURCE" ]]; then

    echo
    echo "[+] Instalando configuración de zram..."

    sudo cp "$ZRAM_SOURCE" "$ZRAM_DEST"

else
    echo "[!] No se encontró:"
    echo "    $ZRAM_SOURCE"
fi

# ------------------------------------------------------------
# 16. Recargar systemd
# ------------------------------------------------------------

echo
echo "[+] Recargando systemd..."

sudo systemctl daemon-reload

# ------------------------------------------------------------
# 17. Activar zram
# ------------------------------------------------------------

if command -v systemctl &>/dev/null; then

    echo "[+] Reiniciando zram..."

    sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true

fi

# ------------------------------------------------------------
# 11. Configurar Fish como shell predeterminado
# ------------------------------------------------------------

if command -v fish &>/dev/null; then

    FISH_PATH="$(command -v fish)"

    if [[ "$SHELL" != "$FISH_PATH" ]]; then
        echo
        echo "[+] Configurando Fish como shell predeterminado..."

        chsh -s "$FISH_PATH"

        echo "[+] Shell predeterminado cambiado a:"
        echo "    $FISH_PATH"
    else
        echo "[+] Fish ya es el shell predeterminado."
    fi

else
    echo "[!] Fish no está instalado."
    echo "    Añádelo a pkglist.txt para instalarlo."
fi

# ------------------------------------------------------------
# 18. Final
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Instalación terminada"
echo "=============================================="
echo
echo "Dotfiles:       $CFG_DIR"
echo "Backup:         $BACKUP_DIR"
echo "Paquetes:       $PKGLIST"
echo "ZRAM:           $ZRAM_DEST"
echo "Xorg:           $XORG_DEST"
echo "Console font:   $CONSOLE_FONT_DIR/Lat2-Fixed16.psf.gz"
echo
echo "Se recomienda reiniciar el sistema:"
echo
echo "    sudo reboot"
echo
