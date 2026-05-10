# Script de Post-Instalación para Debian/Ubuntu

Script automático para Debian, Ubuntu y derivadas con las aplicaciones y paquetes más importantes. Contiene distintas aplicaciones para cada propósito, las que considero más relevantes así como otros paquetes de utilidad.

## Características

- **Interactivo**: Usa un menú gráfico (dialog) para seleccionar qué aplicaciones instalar
- **Gestor de paquetes**: Utiliza `nala` como alternativa más rápida y moderna a `apt`
- **Configuración automática**: Configura repositorios de Debian Trixie
- **Multi-categoría**: Organizado en secciones lógicas para facilitar la selección

## Requisitos

- Distribuciones Debian-base (Debian 12+ / Ubuntu 22.04+)
- Acceso a internet
- Privilegios de sudo
- Terminal con soporte para interfaz gráfica (dialog)

## Uso

### Con sudo disponible
```bash
# 1. Dar permisos de ejecución
chmod +x postinstallappsdebian.sh

# 2. Ejecutar el script
./postinstallappsdebian.sh
```

### Sin sudo instalado (intento automático)
Si no tenés sudo instalado, el script intentará instalarlo automáticamente:
```bash
# 1. Ejecutar como root usando 'su'
su -c "chmod +x postinstallappsdebian.sh && ./postinstallappsdebian.sh"

# O directamente como root
su -c "./postinstallappsdebian.sh"
```

El script detectará si tenés sudo o no y automáticamente intentará configurar sudoers si es necesario.

## Notas

- El script requiere una terminal con soporte para diálogo (no funciona en tty puro sin X)
- Algunas opciones requieren reiniciar el sistema (drivers NVIDIA, etc.)
- El script crea un archivo `resumen_instalacion.txt` en el home con el registro de instalación

## Categorías de Aplicaciones

### Códecs y Drivers
- Codecs Multimedia Globales (Intel/AMD/NVIDIA básica)
- Codecs NVIDIA (VAAPI, VDPAU, NVENC/NVDEC)
- Firmware Linux (firmware-linux, firmware-iwlwifi)
- Xorg básico (servidor X + drivers base)
- Drivers Intel (i915 + aceleración VAAPI)
- Drivers NVIDIA (propietario + CUDA)
- Wayland básico (weston + xwayland)
- Wayland Tools (sway, labwc, river, herramientas)

### Gestión de Discos
- GParted (gestor de particiones)
- NTFS-3g (lectura/escritura discos Windows)
- Exfat-fuse (formato exfat)
- GNOME Disk Utility (gestión de discos)
- SMART Montools (monitoreo S.M.A.R.T.)

### Red y Conectividad
- Network Manager (gestor de red)
- ConnMan (gestor de red alternativo)
- OpenVPN + NetworkManager-OpenVPN
- MTP-tools (Android)
- ifuse + libimobiledevice (iPhone/iPad)

### Sistema
- Actualizar el sistema
- HardInfo2 (info del sistema y benchmark)
- GRUB Customizer (personalizador GRUB)
- ZRAM Tools + Preload (gestión memoria + cache)

### Gestor de Sesión
- LightDM (gestor ligero)
- SDDM (gestor KDE)

### Escritorios
- LXDE (Ligero)
- LXQt (Ligero)
- XFCE (Ligero)
- MATE (Medio)
- Cinnamon (Medio)
- GNOME (Completo)
- KDE Plasma (Completo)

### Window Managers
- i3-wm + i3status (Solarized)
- IceWM (Ligero)

### Audio
- PulseAudio + Pavucontrol
- PipeWire (servidor de audio moderno) + Pavucontrol
- Alsa-utils

### Seguridad
- UFW + GUFW (cortafuegos)
- ClamAV + ClamTK (antivirus)
- BleachBit (limpieza)

### Desarrollo
- Build-essential (compiladores)
- Git (control de versiones)
- Fastfetch (monitor del sistema)
- htop (monitor de procesos)
- btop (monitor moderno)

### File Managers
- Double Commander (doble panel)
- PCManFM (GTK)
- PCManFM-Qt (Qt)
- Thunar (XFCE)
- Krusader (KDE)

### Terminales y Shells
- LXTerminal (LXDE)
- Kitty (moderno, GPU)
- Alacritty (RUST)
- Sakura (libvte)
- XFCE4 Terminal
- Tilix (GNOME)
- Terminator (multi-terminal)
- Terminology (Enlightenment)
- URxvt (rxvt-unicode)
- St (simple terminal)
- Fish (shell interactivo)
- Zsh + plugins (syntax highlighting + autosuggestions)
- Zoxide (navegación de directorios inteligente)

### Compresión y Archivos
- 7zip, rar, unrar, unzip, zip, bzip2, xarchiver

### Ofimática
- Abiword + Gnumeric (suite ofimática)
- LibreOffice (suite ofimática completa)
- FeatherPad (editor de texto)
- qpdfview (visor PDF)
- Wine (ejecutar apps Windows)

### Navegadores
- Firefox ESR
- Firefox (última versión)
- Tor Browser 15.x
- Chromium
- Epiphany (GNOME Web)
- Falkon (Qt WebEngine)
- Midori (navegador ligero)
- Lynx (navegador de texto)
- qutebrowser (navegador vim-like)

### Multimedia
- VLC
- Celluloid
- Haruna (KDE)
- Smplayer + MPV
- Clementine (reproductor de música)
- Ristretto (visor de imágenes)
- WinFF (conversor video/audio)
- SoundConverter (conversor de audio)

### Herramientas Gráficas
- Flameshot (capturas de pantalla)
- Arandr (configurar monitores)

### Utilidades Varias
- IPTVnator 0.19
- Kshutdown (apagar/reniciar)
- AutoCpufreq (ahorro energía)
- LXAppearance (temas y apariencia)
- Nitrogen (gestor de fondos)
- GDebi (instalador de .deb)
- Galculator (calculadora científica)

### Post-Install (apps externas)
- MetaTrader 5 (trading)

### Acciones del Sistema
- Apagar el equipo
- Reiniciar el equipo