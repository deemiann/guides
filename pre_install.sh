#!/bin/bash

# ==============================================================================
# SECCIÓN DE VARIABLES CONFIGURABLES
# ==============================================================================
export NUEVA_INSTALACION_SYSTEMD_BOOT=true      # ¿Es una instalación completamente nueva del cargador de arranque? (true / false)
export PARTICION_RAIZ="/dev/sdaN"               # Tu partición raíz montada previamente
export USUARIO="user"                           # Nombre de tu usuario normal
export PASSWORD_ROOT="rootpass"                 # Contraseña de root
export PASSWORD_USUARIO="userpass"              # Contraseña para tu usuario
export HOSTNAME_PC="hostname"                   # Nombre de la máquina

PKG_CORE="base linux linux-firmware"
PKG_EXTRA="vim networkmanager sudo"
export SERVICIOS="NetworkManager"
PAISES_REFLECTOR="Brazil,Chile,United States"   # Países para el reflector (separados por comas)
export ZONA_HORARIA="America/Lima"              # Tu región (ej. America/Lima)
export LOCALE="es_PE.UTF-8"                     # Idioma a descomentar y configurar
export KEYMAP="dvorak-programmer"               # Distribución de teclado (ej. la-latin1)
export UCODE="intel-ucode"                      # Microcódigo obligatorio: (intel-ucode o amd-ucode)
# ==============================================================================

# Detener el script inmediatamente si ocurre algún error involuntario
set -e

echo "==> [1/12] Configurando Reflector (Espejos más rápidos)..."
reflector -c "$PAISES_REFLECTOR" -l 15 -p https --sort rate --save /etc/pacman.d/mirrorlist

echo "==> [2/12] Inicializando llaves de firma de Pacman..."
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring

echo "==> [3/12] Consolidando lista de paquetes a instalar..."
if [ "$NUEVA_INSTALACION_SYSTEMD_BOOT" = true ]; then
    PKG_CORE="$PKG_CORE $UCODE"
fi

echo "==> [4/12] Ejecutando pacstrap en el punto de montaje /mnt..."
pacstrap -K /mnt $PKG_CORE $PKG_EXTRA

echo "==> [5/12] Generando el archivo de montaje permanente fstab (vía UUID)..."
genfstab -U /mnt >> /mnt/etc/fstab

# Crear el script de automatización interno para el entorno Chroot
cat << 'EOF' > /mnt/config_chroot.sh
#!/bin/bash
set -e

#  Registrar el microcódigo en la base de datos si ya existía el archivo
if [ "$NUEVA_INSTALACION_SYSTEMD_BOOT" = false ]; then
    echo "==> [CHROOT] Registrando microcódigo existente en la base de datos de pacman..."
    pacman -S --overwrite "*" --noconfirm $UCODE
fi

echo "==> [6/12] [CHROOT] Sincronizando zona horaria y reloj de la placa madre..."
ln -sf /usr/share/zoneinfo/"$ZONA_HORARIA" /etc/localtime
hwclock --systohc

echo "==> [7/12] [CHROOT] Configurando idiomas locales y mapa del teclado..."
sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "==> [8/12] [CHROOT] Asignando la identidad de la máquina (Hostname)..."
echo "$HOSTNAME_PC" > /etc/hostname

echo "==> [9/12] [CHROOT] Configurando cuentas de seguridad y contraseñas..."
echo "root:$PASSWORD_ROOT" | chpasswd
useradd -m -G wheel,audio,video,optical,storage -s /bin/bash "$USUARIO"
echo "$USUARIO:$PASSWORD_USUARIO" | chpasswd

# Descomentar la regla del grupo wheel de forma segura
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "==> [10/12] [CHROOT] Compilando imágenes de arranque del Kernel (Initramfs)..."
mkinitcpio -P

echo "==> [11/12] [CHROOT] Inicializando el Cargador de Arranque UEFI (Systemd-boot)..."
if [ "$NUEVA_INSTALACION_SYSTEMD_BOOT" = true ]; then
    bootctl install
fi

cat << LOADER > /boot/loader/loader.conf
default arch.conf
timeout 3
editor no
LOADER

# Obtener dinámicamente el identificador universal UUID de la raíz real
UUID_RAIZ=$(blkid -s UUID -o value "$PARTICION_RAIZ")

cat << ARCHCONF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /$UCODE.img
initrd /initramfs-linux.img
options root=UUID=$UUID_RAIZ rw
ARCHCONF

echo "==> [12/12] [CHROOT] Habilitando servicios esenciales del sistema..."
systemctl enable $SERVICIOS

EOF

# 1. Le damos permisos de ejecución al script desde AFUERA del chroot
chmod +x /mnt/config_chroot.sh

# 2. Ahora lo puedes ejecutar directamente sin anteponer la palabra 'bash'
arch-chroot /mnt /config_chroot.sh

# Copiando install.sh en /mnt
curl -o /mnt/home/demian/install.sh https://raw.githubusercontent.com/deemiann/dotfiles-arch/main/.config/system-backup/install.sh

# Limpieza estricta del entorno
rm -f /mnt/config_chroot.sh

echo "==> [OK] Desmontando todos los sistemas de archivos de forma segura..."
umount -R /mnt

echo "=============================================================================="
echo "      ¡FELICIDADES! LA INSTALACIÓN SE COMPLETÓ CON ÉXITO [12/12 PASOS]        "
echo "=============================================================================="
echo "Ya puedes retirar el USB de instalación y reiniciar el sistema usando: poweroff"
