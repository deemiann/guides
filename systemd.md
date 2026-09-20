# Guía de Instalación de Arch Linux con Systemd-boot

## 0. Preparación del Medio de Instalación
Antes de tocar tu computadora, necesitas descargar el sistema operativo y preparar el dispositivo USB de arranque.

### Descarga y Creación del USB Booteable
1. **Descarga la ISO oficial:** Ve a la página de [Arch Linux](https://archlinux.org) y descarga el archivo `.iso` más reciente.
2. **Grabar la ISO en el USB:**
   * **Opción A (Recomendada en Windows):** Descarga **Rufus**. Selecciona tu USB, elige la ISO de Arch y asegúrate de configurar el esquema de partición en **GPT** y el sistema de destino en **UEFI (no CSM)**. Dale a empezar.
   * **Opción B (Multiboot):** Instala **Ventoy** en tu USB y simplemente arrastra y suelta el archivo ISO dentro de la memoria.

### Configuración de la BIOS/UEFI para arrancar el USB
Para que tu computadora inicie desde el USB en lugar de tu sistema operativo actual, sigue estos pasos:

1. Apaga tu computadora por completo.
2. Conecta el USB booteable en un puerto directo (de preferencia USB 3.0).
3. Enciende el equipo y presiona repetidamente la tecla para entrar a la **BIOS/UEFI** (suele ser `F2`, `F12`, `Del` o `Supr` dependiendo de tu placa madre).
4. **Modificaciones críticas en la BIOS:**
   * **Desactivar Secure Boot:** Busca la opción *Secure Boot* (Arranque seguro) y cámbiala a **Disabled**. Arch Linux no arrancará con esto activo en una instalación estándar.
   * **Modo UEFI nativo:** Asegúrate de que el modo de arranque esté en **UEFI** y no en *Legacy* o *CSM*.
   * **Prioridad de Arranque (Boot Priority):** Mueve tu memoria USB (suele aparecer con el prefijo `UEFI: [Nombre de tu USB]`) a la **posición #1**.
5. Guarda los cambios y sal (usualmente presionando `F10`).

La computadora se reiniciará automáticamente y te mostrará el menú de bienvenida de Arch Linux. Elige la primera opción para cargar la línea de comandos.

---

## 1. Entorno de Pre-instalación
En esta fase prepararás la línea de comandos, asegurarás la conectividad a internet y actualizarás el llavero del sistema.

### Notas de Variantes para este paso:
* **Distribución de teclado (`loadkeys`):** Si usas teclado en español latinoamericano usa `la-latin1`. Si es español de España usa `es`. Para ver la lista completa usa: `localectl list-keymaps`.
* **Nombre del dispositivo inalámbrico (`deviceName`):** Suele empezar por `wlan` o `wlp`. Lo verás reflejado al ejecutar `device list` dentro de `iwctl`.

### Configuración de periféricos y red
```console
# Cargar distribución de teclado
$ loadkeys *[distribucion_teclado]*

# Conectarse a WIFI (Opcional si usas cable)
$ iwctl
[iwctl]# device list
[iwctl]# station *[deviceName]* scan
[iwctl]# station *[deviceName]* get-networks
[iwctl]# station *[deviceName]* connect *[SSID]*

# Verificar conexión
$ ping google.com
```

### Sincronización e inicialización de llaves
```console
# Sincronizar hora del sistema
$ timedatectl set-ntp true
$ timedatectl status

# Inicializar llaves de pacman para evitar errores de firma
$ pacman-key --init
$ pacman-key --populate archlinux
$ pacman -Sy archlinux-keyring
```

---

## 2. Particionado y Sistemas de Archivos
Identificación del disco, creación de la tabla de particiones GPT, formateo y montaje de las unidades.

### Notas de Variantes para este paso:
* **Identificar HDD o SSD:** Ejecuta `lsblk -d -o name,rota`. Si el valor bajo `ROTA` es `1`, el disco es mecánico (**HDD**). Si es `0`, es de estado sólido (**SSD**). Esto te servirá para saber qué optimizaciones aplicar en el futuro.
* **Nombre del Disco y Particiones (`/dev/sdX` o `/dev/nvmeXnX`):** Los discos SATA se nombran `sda`, `sdb`, etc. Los NVMe se nombran `nvme0n1`. Asegúrate de reemplazar `sda1` y `sda2` por tus identificadores reales según la salida de `lsblk`.

### Preparación del disco
```console
# Verificar modo de arranque (Debe devolver 64 o 32)
$ cat /sys/firmware/efi/fw_platform_size

# Ver discos disponibles
$ lsblk
$ fdisk -l

# Crear particiones (Seleccionar tipo de tabla: gpt)
$ cfdisk /dev/*[nombre_disco]*
```
* **Partición 1 (EFI):** Tamaño `1G` | Tipo `EFI System` (Ej: `/dev/sda1` o `/dev/nvme0n1p1`)
* **Partición 2 (Raíz):** Tamaño `Restante` | Tipo `Linux root (x86-64)` (Ej: `/dev/sda2` o `/dev/nvme0n1p2`)

### Formateo y montaje
```console
# Crear sistemas de archivos
$ mkfs.fat -F 32 /dev/*[particion_efi]*
$ mkfs.ext4 /dev/*[particion_raiz]*

# Montar particiones en el entorno de instalación
$ mount /dev/*[particion_raiz]* /mnt
$ mount /dev/*[particion_efi]* /mnt/boot --mkdir
```

---

## 3. Instalación de la Base del Sistema
Descarga de los paquetes esenciales y generación de la tabla de montajes.

### Notas de Variantes para este paso:
* **Procesador Intel o AMD (`ucode`):** Si tu procesador es Intel, debes instalar `intel-ucode`. Si es AMD, debes reemplazarlo por `amd-ucode`.

```console
# Instalar sistema base, microcódigo según procesador y herramientas
$ pacstrap -K /mnt base base-devel linux linux-firmware *[intel-ucode o amd-ucode]* vim networkmanager git

# Generar archivo fstab mediante UUID
$ genfstab -U /mnt >> /mnt/etc/fstab
```

---

## 4. Configuración del Sistema (Chroot)
Ingreso al nuevo sistema para configurar la localización, reloj, red y usuarios.

### Notas de Variantes para este paso:
* **Zona Horaria:** Reemplaza `America/Lima` por tu región. Puedes listar las disponibles con `timedatectl list-timezones`.
* **Idioma Local (`locale`):** Formato `idioma_PAIS`. Ejemplos: `es_PE` (Perú), `es_MX` (México), `es_ES` (España).
* **Nombre de Host (`hostname`):** El nombre único que le darás a tu computadora en la red.
* **Nuevo Usuario:** El nombre de cuenta personal que vas a utilizar (en minúsculas y sin espacios).

### Zona horaria y localización
```console
# Entrar al nuevo sistema delegando la sesión a un servicio transitorio de systemd
$ arch-chroot -S /mnt

# Configurar reloj y zona horaria
$ ln -sf /usr/share/zoneinfo/*[Continente/Ciudad]* /etc/localtime
$ hwclock --systohc

# Configurar el idioma local
$ vim /etc/locale.gen
```
*(Desmarcar tu línea correspondiente en locale.gen, por ejemplo: `es_PE.UTF-8 UTF-8`)*
```vim
#*[idioma_PAIS]*.UTF-8 UTF-8
```
```console
# Generar locales y establecer configuraciones persistentes
$ locale-gen
$ echo "LANG=*[idioma_PAIS]*.UTF-8" > /etc/locale.conf
$ echo "KEYMAP=*[distribucion_teclado]*" > /etc/vconsole.conf
```

### Red y cuentas de usuario
```console
# Definir nombre de la máquina
$ echo "*[nombre_hostname]*" > /etc/hostname

# Configurar archivo hosts
$ vim /etc/hosts
```
*(Contenido de hosts)*
```vim
127.0.0.1        localhost
::1              localhost
127.0.1.1        *[nombre_hostname]*.localdomain *[nombre_hostname]*
```
```console
# Crear contraseña para el usuario root
$ passwd

# Agregar usuario normal y asignarle grupos
$ useradd -m *[nombre_usuario]*
$ passwd *[nombre_usuario]*
$ usermod -aG wheel,audio,video,optical,storage *[nombre_usuario]*

# Dar permisos de sudo al grupo wheel
$ vim /etc/sudoers
```
*(Desmarcar la línea `%wheel ALL=(ALL:ALL) ALL` en sudoers)*
```vim
## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
```

---

## 5. Cargador de Arranque y Finalización
Generación del initramfs, instalación de Systemd-boot y activación de servicios esenciales.

### Notas de Variantes para este paso:
* **Microcódigo en el arranque:** Asegúrate de escribir `intel-ucode.img` o `amd-ucode.img` en el archivo de configuración `arch.conf` según el procesador instalado en el paso 3.

```console
# Crear la imagen initramfs inicial
$ mkinitcpio -P

# Instalar systemd-boot en la partición EFI
$ bootctl install
$ mkdir -p /boot/loader/entries

# Configurar el menú del cargador
$ vim /boot/loader/loader.conf
```
*(Contenido de loader.conf)*
```vim
default arch
timeout 3
editor no
```
```console
# Presiona ENTER tras la primera línea ($). Los símbolos '>' aparecerán solos.
# El comando resolverá el UUID real de tu disco y guardará el archivo al escribir EOF.
$ cat << EOF > /boot/loader/entries/arch.conf
> title Arch Linux
> linux /vmlinuz-linux
> initrd /*[intel-ucode o amd-ucode]*.img
> initrd /initramfs-linux.img
> options root=UUID=$(blkid -s UUID -o value /dev/*[particion_raiz]*) rw
> EOF
```

### Servicios finales y reinicio
```console
# Habilitar servicios de red y actualización automática del cargador
$ systemctl enable NetworkManager.service
$ systemctl enable systemd-boot-update.service

# Salir del entorno chroot
$ exit

# Desmontar todas las particiones de forma segura para evitar pérdida de datos
$ umount -R /mnt

# Apagar el equipo por completo
$ poweroff
```

---

## 6. Primer Arranque y Post-Instalación
Sigue estos pasos cruciales antes de encender tu computadora nuevamente.

1. **Retirar el USB booteable:** Una vez que la pantalla se apague por completo, **desconecta el USB** de instalación de Arch Linux para evitar que el equipo vuelva a arrancar el instalador.
2. **Configurar el orden de arranque (Boot Order):**
   * Enciende el equipo y presiona inmediatamente la tecla de acceso a tu **BIOS/UEFI** (usualmente `F2`, `F12`, `Del` o `Supr`).
   * Dirígete a la pestaña **Boot** (Arranque).
   * Asegúrate de que **Linux Boot Manager** (el nombre que registra Systemd-boot) esté en el **primer lugar (#1)** de la prioridad de arranque, por encima de tu disco duro genérico o cualquier otra opción.
   * Guarda los cambios y sal (normalmente presionando `F10`).
3. **¡Listo!** El sistema se reiniciará y verás el menú de Systemd-boot con la opción "Arch Linux" lista para cargar tu nuevo sistema.
