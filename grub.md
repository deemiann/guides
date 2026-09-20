# Guia de Instalacion de Arch Linux con Grub

## Cargar teclado
```console
$ loadkeys dvorak-programmer
```

## Verificar si hay internet
```console
$ ping google.com
```

## Conectarse a WIFI
```console
$ iwctl
$ device list
$ station "deviceName" scan
$ station "deviceName" get-networks
$ station "deviceName" connect "SSID"
```

## Sincronizar hora
```console
$ timedatectl set-ntp true
$ timedatectl status
```

## Inicialización de llaves GPG
```console
$ pacman-key --init
$ pacman-key --populate archlinux
$ pacman -Sy archlinux-keyring
```

## Ver particiones 
```console
$ lsblk
$ fdisk -l
```

## Particiones
### Verificar si es EFI
```console
$ cat /sys/firmware/efi/fw_platform_size
```
### Crear particiones
```console
$ cfdisk
```

#### Seleccionar gpt
1. **dev/sda1**
    * **size:** 1G
    * **type:** EFI System
    * **write**
2. **dev/sda2:** 
    * **size:** restante
    * **type:** Linux
    * **write**

## Systema de Archivos
```console
$ mkfs.fat -F 32 /dev/sda1
$ mkfs.ext4 /dev/sda2
```

## Montar particiones
```console
$ mount /dev/sda2 /mnt
$ mkdir -p /mnt/boot/efi    # crear efi
$ mount /dev/sda1 /mnt/boot/efi 
```

## Instalar paquetes en /mnt
```console
$ pacstrap -K /mnt base base-devel linux linux-firmware vim efibootmgr grub networkmanager
```
---

```console
$ genfstab -U /mnt >> /mnt/etc/fstab
```

```console
$ arch-chroot -S /mnt
```

```console
$ ln -sf /usr/share/zoneinfo/America/Lima /etc/localtime
```

```console
$ hwclock --systohc
```

```console
$ echo "ArchLinux" > /etc/hostname
```
---
```console $ vim /etc/hosts ```
```vim
127.0.0.1        localhost
::1              localhost
127.0.1.1        ArchLinux.localdomain ArchLinux
```
---
```console
$ echo "KEYMAP=dvorak-programmer" > /etc/vconsole.conf
$ echo "LANG=es_PE.UTF-8" > /etc/locale.conf
```
---
```console
$ vim /etc/locale.gen
```
desmarcar **es_PE.UTF-8 UTF-8**
```console
#es_PA ISO-8859-1  
es_PE.UTF-8 UTF-8  
#es_PE ISO-8859-1  
```
```console
$ locale-gen
```
---
## Contrasena root
```console
$ passwd
```
## Agregar usuario
```console
$ useradd -m demian
$ passwd demian
```
## Agregar a Grupos
```console
$ usermod -aG wheel,audio,video,optical,storage demian
```
---
## Sudo
```console
$ visudo
```
```vim
## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
```
---
## Networkmanager
```console
$ systemctl enable NetworkManager.service
```
## Grub
```console
$ grub-install --efi-directory=/boot/efi --bootloader-id='Arch Linux' --target=x86_64-efi
$ grub-mkconfig -o /boot/grub/grub.cfg
```

## Ultimo
```console
$ mkinitcpio -P
$ exit
$ shutdown now
```
