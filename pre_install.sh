#!/bin/bash

# ==============================================================================
# SECCIÓN DE VARIABLES CONFIGURABLES (Modifica esto a tu gusto)
# ==============================================================================
PARTICION_RAIZ="/dev/root"      # Tu partición raíz montada previamente
ZONA_HORARIA="Continent/Country"     # Tu región (ej. America/Lima)
LOCALE="id_Country.UTF-8"            # Idioma a descomentar y configurar
KEYMAP="layout"      # Distribución de teclado (ej. dvorak-programmer)
FONT="Lat2-Fixed16"             # Fuente de consola
HOSTNAME_PC="hostname"            # Nombre de la máquina
USUARIO="user"                # Nombre de tu usuario normal
PASSWORD_ROOT="rootpsw"            # Contraseña de root
PASSWORD_USUARIO="userpsw"  # Contraseña para tu usuario


# ¿Es una instalación completamente nueva de systemd-boot? (true / false)
# Si es true, ejecuta 'bootctl install'.
NUEVA_INSTALACION_SYSTEMD_BOOT=true

# ¿Es una instalación completamente nueva de Arch que no instalo los microcódigo o no?
# Si es true, incluye el microcódigo (intel-ucode/amd-ucode) en pacstrap.
NUEVA_INSTALACION_MICRO_CODIGO=true
# ==============================================================================

# Detener el script si ocurre algún error
set -e

echo "==> [1/6] Detectando hardware..."
# Detección automática del microcódigo según el fabricante de la CPU
if grep -q "Intel" /proc/cpuinfo; then
    UCODE="intel-ucode"
    echo "    -> Procesador Intel detectado."
elif grep -q "AMD" /proc/cpuinfo; then
    UCODE="amd-ucode"
    echo "    -> Procesador AMD detectado."
else
    UCODE=""
    echo "    -> No se detectó Intel ni AMD claramente, se omite ucode."
fi

# Detección automática si el sistema arrancó en modo UEFI o Legacy (BIOS)
if [ -d "/sys/firmware/efi/efivars" ]; then
    MODO_EFI=true
    echo "    -> Sistema en modo EFI detectado."
else
    MODO_EFI=false
    echo "    -> Sistema en modo BIOS (Legacy) detectado."
fi

echo "==> [2/6] Ejecutando pacstrap y generando fstab..."

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring

# Si es una instalación nueva del sistema, añadimos el ucode correspondiente
if [ "$NUEVA_INSTALACION_MICRO_CODIGO" = true ]; then
    if [ -n "$UCODE" ]; then
        pacstrap -K /mnt base linux linux-firmware "$UCODE" vim networkmanager sudo
    fi
else
    pacstrap -K /mnt base linux linux-firmware vim networkmanager sudo
fi

# Generar el archivo fstab mediante UUID
genfstab -U /mnt >> /mnt/etc/fstab

# Copiar fuente
#cp Lat2-Fixed16.psf.gz /mnt/usr/share/kbd/consolefonts
curl -o /mnt/usr/share/kbd/consolefonts/Lat2-Fixed16.psf.gz https://raw.githubusercontent.com/deemiann/dotfiles-arch/main/.config/systemd-backup/Lat2-Fixed16.psf.gz

# Crear script config_chroot.sh
cat << 'EOF' > /mnt/config_chroot.sh
#!/bin/bash
set -e

# Recibir variables pasadas desde fuera del chroot
ZONA_HORARIA="$1"
LOCALE="$2"
KEYMAP="$3"
FONT="$4"
HOSTNAME_PC="$5"
USUARIO="$6"
PASSWORD_ROOT="$7"
PASSWORD_USUARIO="$8"
UCODE="$9"
PARTICION_RAIZ="${10}"
NUEVA_INSTALACION_SYSTEMD_BOOT="${11}"
MODO_EFI="${12}"

echo " -> Configurando reloj y zona horaria..."
ln -sf /usr/share/zoneinfo/"$ZONA_HORARIA" /etc/localtime
hwclock --systohc

echo " -> Configurando idioma y teclado..."
# Desmarcar locale correspondiente en locale.gen
sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen

echo "LANG=$LOCALE" > /etc/locale.conf
cat << VCONF > /etc/vconsole.conf
KEYMAP=$KEYMAP
FONT=$FONT
VCONF

echo " -> Configurando Hostname y Red..."
echo "$HOSTNAME_PC" > /etc/hostname

echo " -> Estableciendo contraseña de root..."
echo "root:$PASSWORD_ROOT" | chpasswd

echo " -> Creando usuario y asignando grupos..."
useradd -m "$USUARIO"
echo "$USUARIO:$PASSWORD_USUARIO" | chpasswd
usermod -aG wheel,audio,video,optical,storage "$USUARIO"

echo " -> Habilitando sudo para el grupo wheel..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo " -> Generando initramfs..."
mkinitcpio -P

echo " -> Configurando Cargador de Arranque (Systemd-boot)..."
if [ "$MODO_EFI" = true ]; then
    if [ "$NUEVA_INSTALACION_SYSTEMD_BOOT" = true ]; then
        bootctl install
        cat << LOADER > /boot/loader/loader.conf
default arch.conf
timeout 3
editor no
LOADER
    fi

    # Obtener el UUID real de la partición raíz
    UUID_RAIZ=$(blkid -s UUID -o value "$PARTICION_RAIZ")

    # Definir la línea initrd del ucode si existe
    if [ -n "$UCODE" ]; then
        INITRD_UCODE="initrd /$UCODE.img"
    else
        INITRD_UCODE=""
    fi

    cat << ARCHCONF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
$INITRD_UCODE
initrd /initramfs-linux.img
options root=UUID=$UUID_RAIZ rw
ARCHCONF
else
    echo "    -> El sistema no está en modo EFI. Se omite la instalación de Systemd-boot por defecto."
fi

echo " -> Habilitando servicios de red..."
systemctl enable NetworkManager.service
systemctl enable systemd-boot-update.service || true

EOF

#cp config_chroot.sh /mnt/config_chroot.sh

arch-chroot /mnt bash /config_chroot.sh "$ZONA_HORARIA" "$LOCALE" "$KEYMAP" "$FONT" "$HOSTNAME_PC" "$USUARIO" "$PASSWORD_ROOT" "$PASSWORD_USUARIO" "$UCODE" "$PARTICION_RAIZ" "$NUEVA_INSTALACION_SYSTEMD_BOOT" "$MODO_EFI"

# Copiar fuente
curl -o /mnt/usr/share/kbd/consolefonts/Lat2-Fixed16.psf.gz https://raw.githubusercontent.com/deemiann/dotfiles-arch/main/.config/systemd-backup/Lat2-Fixed16.psf.gz
# Copiar install.sh
curl -o /mnt/home/demian/install.sh https://raw.githubusercontent.com/deemiann/dotfiles-arch/main/.config/systemd-backup/install.sh

# Limpiar archivo temporal
rm /mnt/config_chroot.sh

echo "==> [4/6] Desmontando particiones de forma segura..."
umount -R /mnt

echo "==> [5/6] ¡Instalación y configuración completadas con éxito!"
echo "==> [6/6] Ya puedes apagar o reiniciar el equipo usando: poweroff"
