#!/usr/bin/env bash
# =====================================================================
# SCRIPT DE PRE-INSTALACIÓN - ARCH LINUX AUTOMATIZADO
# =====================================================================
set -e

# =====================================================================
# PANEL DE CONFIGURACIÓN PRINCIPAL (Modifica esto según tus necesidades)
# =====================================================================
HOSTNAME="ArchLinux"
PASS_ROOT="ggmitre"
NUEVO_USUARIO="demian"
PASS_USUARIO="terrible"

# Configuración Regional
ZONA_HORARIA="America/Lima"
TECLADO="dvorak-programmer"
IDIOMA="es_PE.UTF-8"
LOCALE_LINE="es_PE.UTF-8 UTF-8"

# Selección de Software
PAQUETES_SISTEMA="base linux linux-firmware intel-ucode"
PAQUETES_HERRAMIENTAS="xorg-server xorg-xinit mesa sudo i3-wm ttf-dejavu gnu-free-fonts alacritty feh vim iwd firefox pipewire pipewire-alsa pipewire-pulse wireplumber git i3status-rust dmenu"

DISK="/dev/sda"
# =====================================================================
# Limpieza de tablas previas
##sgdisk --zap-all "$DISK"

### Esquema solicitado: 1G EFI, 4G Swap, 40G Root, Restante Home
##sfdisk --label gpt "$DISK" <<EOF
##size=1G,  type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI System"
##size=4G,  type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F, name="Linux swap"
##size=45G, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="Linux Root"
##type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="Linux Home"
##EOF

# boot formating
#mkfs.vfat -F32 "${DISK}1"
mkswap "${DISK}2"
swapon "${DISK}2"
mkfs.ext4 -F "${DISK}3"
#mkfs.ext4 -F "${DISK}4"

# Primero la raíz raíz (/) para no pisar montajes posteriores
mount "${DISK}3" /mnt

# Estructura interna
mkdir -p /mnt/boot
mkdir -p /mnt/home

# Montajes secundarios
mount "${DISK}1" /mnt/boot
mount "${DISK}4" /mnt/home

pacstrap /mnt $PAQUETES_SISTEMA $PAQUETES_HERRAMIENTAS

genfstab -U /mnt >> /mnt/etc/fstab

cp /root/dotfiles /mnt -r

# Pasar todas las variables posicionales al script secundario
arch-chroot /mnt bash /dotfiles/chroot.sh \
  "$DISK" \
  "$NUEVO_USUARIO" \
  "$PASS_USUARIO" \
  "$PASS_ROOT" \
  "$ZONA_HORARIA" \
  "$TECLADO" \
  "$IDIOMA" \
  "$LOCALE_LINE" \
  "$HOSTNAME"

# configurando resolv.conf
#echo "nameserver 1.1.1.1" >> /mnt/etc/resolv.conf
#echo "nameserver 8.8.8.8" >> /mnt/etc/resolv.conf

#eliminando el dotfiles
rm /mnt/dotfiles -rf
umount -R /mnt
reboot
