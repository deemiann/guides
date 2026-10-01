#!/bin/bash

# ==============================================================================
# SECCIÓN DE VARIABLES CONFIGURABLES
# ==============================================================================
export PARTICION_RAIZ="/dev/sdaN"               # Tu partición raíz montada previamente
export USUARIO="user"                           # Nombre de tu usuario normal
export PASSWORD_ROOT="rootpass"                 # Contraseña de root
export PASSWORD_USUARIO="userpass"              # Contraseña para tu usuario
export HOSTNAME_PC="hostname"                   # Nombre de la máquina

export NUEVA_INSTALACION_SYSTEMD_BOOT=false      # ¿Es una instalación completamente nueva del cargador de arranque? (true / false)
PKG_CORE="base linux linux-firmware"
PKG_EXTRA="vim networkmanager sudo"
export SERVICIOS="NetworkManager"
PAISES_REFLECTOR="Brazil,Chile,United States"   # Países para el reflector (separados por comas)
export ZONA_HORARIA="America/Lima"              # Tu región (ej. America/Lima)
export LOCALE="es_PE.UTF-8"                     # Idioma a descomentar y configurar
export KEYMAP="dvorak-programmer"               # Distribución de teclado (ej. la-latin1)
export FONT="Lat2-Fixed16"                      # Fuente de tty (ej. default8x16)
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

cat << VCONF > /etc/vconsole.conf
KEYMAP=$KEYMAP
FONT=$FONT
VCONF

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
options root=UUID=$UUID_RAIZ rw vt.cur_default=0
ARCHCONF

echo "==> [12/12] [CHROOT] Habilitando servicios esenciales del sistema..."
systemctl enable $SERVICIOS

# INTEGRACIÓN 2: Crear el servicio personalizado para inyectar tus colores Gruvbox en el arranque de la TTY
echo "==> [CHROOT] Creando servicio para el esquema de colores Gruvbox en la TTY..."
cat << 'TTYCOLORS' > /etc/systemd/system/tty-retrobox-dark.service
[Unit]
Description=Aplicar esquema de colores Gruvbox a las TTYs de forma temprana
After=systemd-vconsole-setup.service

[Service]
Type=oneshot
ExecStart=/usr/bin/sh -c 'for tty in /dev/tty[1-6]; do echo -ne "\\e]P01C1C1C\\e]P1CC241D\\e]P298971A\\e]P3D79921\\e]P4458588\\e]P5B16286\\e]P6689D6A\\e]P7A89984\\e]P8928374\\e]P9FB5944\\e]PAB8BB26\\e]PBFABD2F\\e]PC83A598\\e]PDD3869B\\e]PE8EC07C\\e]PFEBDBB2\\e[2J\\e[H" > "$tty"; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
TTYCOLORS

# Habilitar el nuevo servicio de colores de manera nativa dentro del Chroot
systemctl enable tty-retrobox-dark.service

EOF

# Copiando fuente a /mnt
curl -o /mnt/usr/share/kbd/consolefonts/Lat2-Fixed16.psf.gz https://raw.githubusercontent.com/deemiann/dotfiles-arch/main/.config/system-backup/Lat2-Fixed16.psf.gz

# ejecucion de config_chroot.sh en /mnt
arch-chroot /mnt bash /config_chroot.sh

# Copiando install.sh en /mnt
curl -o /mnt/home/$USUARIO/install.sh https://raw.githubusercontent.com/deemiann/dotfiles-arch/main/.config/system-backup/install.sh

# Limpieza estricta del entorno
rm -f /mnt/config_chroot.sh

echo "==> [OK] Desmontando todos los sistemas de archivos de forma segura..."
umount -R /mnt

echo "=============================================================================="
echo "      ¡FELICIDADES! LA INSTALACIÓN SE COMPLETÓ CON ÉXITO [12/12 PASOS]        "
echo "=============================================================================="
echo "Ya puedes retirar el USB de instalación y reiniciar el sistema usando: poweroff"
