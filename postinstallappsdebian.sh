#!/bin/bash

# ============================================
# VERIFICACIÓN Y CONFIGURACIÓN DE SUDO INICIAL
# ============================================
# Esta sección debe ejecutarse ANTES de cualquier comando privilegiado
# para asegurar que el usuario tenga acceso sudo configurado correctamente

CURRENT_USER=$(whoami)

# Función para verificar acceso sudo de forma robusta
# Maneja: sudo como grupo primario, secundario, y formato con sufijo dos puntos (sudo:)
check_sudo_access() {
    # Primary: usar id -nG que maneja grupos secundarios correctamente
    # Obtener grupos y normalizar eliminando sufijo dos puntos
    for group in $(id -nG 2>/dev/null); do
        # Eliminar sufijo dos puntos si existe (sudo: -> sudo)
        group_clean="${group%:}"

        if [ "$group_clean" = "sudo" ] || [ "$group_clean" = "root" ]; then
            return 0
        fi
    done

    # Fallback: verificar si el grupo sudo existe en el sistema
    if getent group sudo >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Función para agregar usuario al archivo sudoers (usando visudo para seguridad)
add_user_to_sudoers() {
    local username="$1"
    local sudoers_file="/etc/sudoers"
    local lock_file="${sudoers_file}.lock"
    local temp_file

    echo "Agregando usuario $username a $sudoers_file..."

    # Verificar que visudo esté disponible
    if ! command -v visudo &> /dev/null; then
        echo "ERROR: visudo no está disponible."
        return 1
    fi

    # Verificar sintaxis del sudoers antes de editar
    if ! visudo -qc 2>&1; then
        echo "ERROR: El archivo sudoers tiene errores de sintaxis."
        return 1
    fi

    # Esperar si hay otro proceso editando sudoers
    while [ -f "$lock_file" ]; do
        sleep 1
    done

    # Crear lock file
    touch "$lock_file" || {
        echo "ERROR: No se puede crear el archivo de lock."
        return 1
    }

    # Limpiar lock file al salir
    trap "rm -f '$lock_file'" EXIT INT TERM

    # Entradas a agregar
    local requiretty_entry="Defaults:${username} !requiretty"
    local sudo_entry="${username} ALL=(root) NOPASSWD: ALL"

    # Verificar si la entrada de requiretty ya existe
    if ! grep -q "^${requiretty_entry}" "$sudoers_file" 2>/dev/null; then
        echo "$requiretty_entry" >> "$sudoers_file" || {
            echo "ERROR: No se puede agregar entradaDefaults a sudoers."
            rm -f "$lock_file"
            return 1
        }
    fi

    # Verificar si la entrada de sudo ya existe
    if ! grep -q "^${sudo_entry}" "$sudoers_file" 2>/dev/null; then
        echo "$sudo_entry" >> "$sudoers_file" || {
            echo "ERROR: No se puede agregar entrada de sudo a sudoers."
            rm -f "$lock_file"
            return 1
        }
    fi

    # Verificar sintaxis después de editar
    if ! visudo -qc 2>&1; then
        echo "ERROR: La sintaxis del sudoers es incorrecta después de los cambios."
        rm -f "$lock_file"
        return 1
    fi

    # Establecer permisos correctos
    chmod 0440 "$sudoers_file" || {
        echo "WARNING: No se pudieron establecer permisos 440 en sudoers."
    }
    chown root:root "$sudoers_file" || {
        echo "WARNING: No se pudo establecer propietario root:root en sudoers."
    }

    rm -f "$lock_file"
    trap - EXIT INT TERM

    echo "Usuario $username agregado a sudoers correctamente."
    return 0
}

# Función para verificar si el usuario ya está en sudoers
user_in_sudoers() {
    local username="$1"
    local sudoers_file="/etc/sudoers"

    if [ -f "$sudoers_file" ] && grep -q "^${username} ALL=" "$sudoers_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

echo "=== Verificando configuración de sudo ==="

# Verificar si el usuario ya tiene acceso sudo (por grupo o por sudoers)
if check_sudo_access; then
    echo "Usuario $CURRENT_USER ya tiene acceso sudo (por grupo). Continuando..."
    HAS_SUDO=true
elif user_in_sudoers "$CURRENT_USER"; then
    echo "Usuario $CURRENT_USER ya tiene acceso sudo (por sudoers). Continuando..."
    HAS_SUDO=true
else
    echo "Usuario $CURRENT_USER NO tiene acceso sudo. Configurando..."
    HAS_SUDO=false

    # Verificar si sudo está instalado
    if ! command -v sudo &> /dev/null; then
        echo "sudo no está instalado. Intentando instalar..."

        # Intentar instalar sudo como root (sin sudo)
        if [ "$(id -u)" -eq 0 ]; then
            # Somos root, instalar directamente
            apt update && apt install -y sudo
            echo "sudo instalado correctamente."
        else
            # No somos root y no tenemos sudo -> intentar con su
            echo "Intentando instalar sudo usando 'su'..."
            if command -v su &> /dev/null; then
                su -c "apt update && apt install -y sudo"
                echo "sudo instalado mediante su."
            else
                echo "ERROR: No se puede instalar sudo. Necesitas ejecutarlo como root o tener acceso su."
                exit 1
            fi
        fi
    fi

    # Ahora sudo debería estar instalado, añadir usuario al archivo sudoers
    if command -v visudo &> /dev/null; then
        # Primero intentar agregar al grupo sudo (método tradicional)
        if getent group sudo >/dev/null 2>&1; then
            echo "Agregando usuario $CURRENT_USER al grupo sudo..."
            if [ "$(id -u)" -eq 0 ]; then
                usermod -aG sudo "$CURRENT_USER"
            else
                sudo usermod -aG sudo "$CURRENT_USER" 2>/dev/null || true
            fi

            if check_sudo_access; then
                echo "Usuario agregado al grupo sudo correctamente."
                HAS_SUDO=true
            fi
        fi

        # Si no funcionó por grupo, agregar directamente a sudoers
        if [ "$HAS_SUDO" != "true" ]; then
            echo "Intentando agregar usuario directamente a sudoers..."
            if add_user_to_sudoers "$CURRENT_USER"; then
                HAS_SUDO=true
            fi
        fi

        # Verificación final
        if [ "$HAS_SUDO" = "true" ]; then
            echo "Usuario $CURRENT_USER tiene acceso sudo configurado."
        else
            echo "ERROR: No se pudo configurar el acceso sudo."
            exit 1
        fi
    else
        echo "ERROR: visudo no está disponible."
        exit 1
    fi
fi

echo "=== Verificando configuración de sudo ==="

# Verificar si el usuario ya tiene acceso sudo
if check_sudo_access; then
    echo "Usuario $CURRENT_USER ya tiene acceso sudo. Continuando..."
    HAS_SUDO=true
else
    echo "Usuario $CURRENT_USER NO tiene acceso sudo. Configurando..."
    HAS_SUDO=false

    # Verificar si sudo está instalado
    if ! command -v sudo &> /dev/null; then
        echo "sudo no está instalado. Intentando instalar..."

        # Intentar instalar sudo como root (sin sudo)
        if [ "$(id -u)" -eq 0 ]; then
            # Somos root, instalar directamente
            apt update && apt install -y sudo
            echo "sudo instalado correctamente."
        else
            # No somos root y no tenemos sudo -> intentar con su
            echo "Intentando instalar sudo usando 'su'..."
            if command -v su &> /dev/null; then
                su -c "apt update && apt install -y sudo"
                echo "sudo instalado mediante su."
            else
                echo "ERROR: No se puede instalar sudo. Necesitas ejecutarlo como root o tener acceso su."
                exit 1
            fi
        fi
    fi

    # Ahora sudo debería estar instalado, añadir usuario al grupo sudo
    if command -v sudo &> /dev/null; then
        # Verificar si el grupo sudo existe
        if getent group sudo >/dev/null 2>&1; then
            echo "Agregando usuario $CURRENT_USER al grupo sudo..."

            if [ "$(id -u)" -eq 0 ]; then
                # Somos root,可以直接用usermod
                usermod -aG sudo "$CURRENT_USER"
            else
                # Usar sudo si está disponible
                sudo usermod -aG sudo "$CURRENT_USER"
            fi

            # Verificar que la adición funcionó
            if check_sudo_access; then
                echo "Usuario agregado al grupo sudo correctamente."
            else
                echo "ERROR: No se pudo agregar usuario al grupo sudo."
                exit 1
            fi
        else
            echo "ERROR: El grupo sudo no existe en el sistema."
            exit 1
        fi
    fi

    HAS_SUDO=true
fi

# Verificación final: asegurar que todo funcione
echo ""
echo "=== Verificando configuración final ==="

# Verificar que sudo existe
if ! command -v sudo &> /dev/null; then
    echo "ERROR: sudo no está instalado."
    exit 1
fi
echo "[OK] sudo está instalado"

# Verificar que el usuario está en el grupo sudo
if check_sudo_access; then
    echo "[OK] Usuario $CURRENT_USER está en grupo sudo"
else
    echo "ERROR: Usuario no tiene acceso sudo después de la configuración."
    exit 1
fi

# Verificar que los repos funcionan
echo "[OK] Verificando repositorios..."
apt update -qq 2>/dev/null || {
    echo "ERROR: No se pueden actualizar los repositorios."
    exit 1
}
echo "[OK] Repositorios funcionan correctamente"

echo ""
echo "=== Configuración de sudo completada exitosamente ==="
echo ""

# Guardar el usuario que ejecutará las instalaciones (para permisos correctos)
TARGET_USER="$CURRENT_USER"
if [ "$(id -u)" -eq 0 ]; then
    # Si somos root,我们需要 guardar el usuario original para dar permisos
    # El usuario al que se añadirá al grupo sudo
    RUN_AS_USER="$CURRENT_USER"
else
    RUN_AS_USER="$CURRENT_USER"
fi

# Función para ejecutar comandos con o sin sudo
# IMPORTANTE: Mantiene permisos del usuario, no de root
run_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        # Somos root - ejecutar directamente pero con verificación de errores
        # Los archivos se crearán como root, se corregirán al final
        "$@"
        return $?
    elif [ "$HAS_SUDO" = true ]; then
        sudo -n "$@" 2>/dev/null && return $? || sudo "$@"
        return $?
    else
        "$@"
        return $?
    fi
}

# Al final del script, corregir permisos del usuario
fix_permissions() {
    if [ "$(id -u)" -eq 0 ] && [ -n "$TARGET_USER" ]; then
        local user_home
        user_home=$(getent passwd "$TARGET_USER" | cut -d: -f6)
        if [ -n "$user_home" ] && [ -d "$user_home" ]; then
            echo "=== Corrigiendo permisos para usuario $TARGET_USER ==="
            chown -R "$TARGET_USER:$TARGET_USER" "$user_home" 2>/dev/null || true
        fi
    fi
}

# 3. Ahora configurar repos de Debian Trixie
echo "Configurando repos de Debian Trixie..."

# Limpiar sources.list principal (si existe)
run_cmd rm -f /etc/apt/sources.list

# Limpiar sources.list.d y crear solo el de Trixie
run_cmd rm -f /etc/apt/sources.list.d/*.list

# Escribir nuevo sources.list
run_cmd tee /etc/apt/sources.list << EOF
deb https://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
EOF

# 4. Actualizar repositorios e instalar herramientas básicas
echo "Actualizando repositorios..."
run_cmd apt update
run_cmd apt install -y nala axel git speedtest-cli dialog

# Recargar grupos para que tenga efecto inmediato
echo "Recargando grupos del usuario..."
NEW_GROUPS=$(groups $CURRENT_USER)

echo "Configuración inicial completada."

# Inicializar variables
log_file="$HOME/resumen_instalacion.txt"
start_time=$(date +%s)
installed_apps=()

# Crear o limpiar el archivo de log
echo "Resumen de instalación - $(date)" > "$log_file"
echo "-----------------------------------" >> "$log_file"

# Medir velocidad de internet y registrar en el archivo de log
if command -v speedtest-cli &> /dev/null; then
    echo "Velocidad de conexión a internet:" >> "$log_file"
    speedtest_result=$(speedtest-cli --simple)
    echo "$speedtest_result" >> "$log_file"
    echo "-----------------------------------" >> "$log_file"
fi

# ============================================
# MENÚ PRINCIPAL - ORDEN PRIORIDAD
# (Lo más básico primero)
# ============================================

echo "Iniciando menú de instalación..."
echo "Si no ves la interfaz, presiona Enter para continuar..."

opciones=$(dialog --stdout --checklist "Selecciona las aplicaciones que deseas instalar:" 0 0 0 \
    "=== CÓDECS Y DRIVERS ===" "" off \
    0 "  Codecs Multimedia Globales (Intel/AMD/NVIDIA básica)" off \
    99 "  Codecs NVIDIA (VAAPI, VDPAU, NVENC/NVDEC)" off \
    1 "  Firmware Linux (firmware-linux, firmware-iwlwifi)" off \
    2 "  Xorg básico (servidor X + drivers base)" off \
    95 "  Drivers Intel (i915 + aceleración VAAPI)" off \
    96 "  Drivers NVIDIA (proprietario + CUDA)" off \
    97 "  Wayland básico (weston + xwayland)" off \
    98 "  Wayland Tools (sway, labwc, river, herramientas)" off \
    "=== GESTIÓN DE DISCOS ===" "" off \
    3 "  GParted (gestor de particiones)" off \
    4 "  NTFS-3g (lectura/escritura discos Windows)" off \
    5 "  Exfat-fuse (formato exfat)" off \
    77 "  GNOME Disk Utility (gestión de discos)" off \
    78 "  SMART Montools (monitoreo S.M.A.R.T.)" off \
    "=== RED Y CONECTIVIDAD ===" "" off \
    6 "  Network Manager (gestor de red)" off \
    72 "  ConnMan (gestor de red alternativo)" off \
    7 "  OpenVPN + NetworkManager-OpenVPN" off \
    8 "  MTP-tools (Android)" off \
    9 "  ifuse + libimobiledevice (iPhone/iPad)" off \
    "=== SISTEMA ===" "" off \
    10 "  Actualizar el sistema" off \
    79 "  HardInfo2 (info del sistema y benchmark)" off \
    80 "  GRUB Customizer (personalizador GRUB)" off \
    81 "  ZRAM Tools (gestión de memoria zRAM)" off \
    "=== GESTOR DE SESIÓN ===" "" off \
    11 "  LightDM (gestor ligero)" off \
    12 "  SDDM (gestor KDE)" off \
    "=== ESCRITORIOS ===" "" off \
    41 "  LXDE (Ligero)" off \
    42 "  LXQt (Ligero)" off \
    57 "  XFCE (Ligero)" off \
    43 "  MATE (Medio)" off \
    44 "  Cinnamon (Medio)" off \
    45 "  GNOME (Completo)" off \
    46 "  KDE Plasma (Completo)" off \
    "=== WINDOW MANAGERS ===" "" off \
    48 "  i3-wm + i3status (Solarized)" off \
    49 "  IceWM (Ligero)" off \
    "=== AUDIO ===" "" off \
    13 "  PulseAudio + Pavucontrol" off \
    89 "  PipeWire (servidor de audio moderno) + Pavucontrol" off \
    14 "  Alsa-utils" off \
    "=== SEGURIDAD ===" "" off \
    15 "  UFW + GUFW (cortafuegos)" off \
    16 "  ClamAV + ClamTK (antivirus)" off \
    17 "  BleachBit (limpieza)" off \
    "=== DESARROLLO ===" "" off \
    18 "  Build-essential (compiladores)" off \
    19 "  Git (control de versiones)" off \
    20 "  Fastfetch (monitor del sistema)" off \
    70 "  htop (monitor de procesos)" off \
    71 "  btop (monitor moderno)" off \
    "=== FILE MANAGERS ===" "" off \
    22 "  Double Commander (doble panel)" off \
    50 "  PCManFM (GTK)" off \
    51 "  PCManFM-Qt (Qt)" off \
    55 "  Thunar (XFCE)" off \
    56 "  Krusader (KDE)" off \
    "=== TERMINALES Y SHELLS ===" "" off \
    58 "  LXTerminal (LXDE)" off \
    59 "  Kitty (moderno, GPU)" off \
    60 "  Alacritty (RUST)" off \
    61 "  Sakura (libvte)" off \
    62 "  XFCE4 Terminal" off \
    63 "  Tilix (GNOME)" off \
    64 "  Terminator (multi-terminal)" off \
    65 "  Terminology (Enlightenment)" off \
    66 "  URxvt (rxvt-unicode)" off \
    67 "  St (simple terminal)" off \
    68 "  Fish (shell interactivo)" off \
    69 "  Zsh + plugins (syntax highlighting + autosuggestions)" off \
    73 "  Zoxide (navegación de directorios inteligente)" off \
    "=== COMPRESIÓN Y ARCHIVOS ===" "" off \
    21 "  7zip, rar, unrar, unzip, zip, bzip2, xarchiver" off \
    "=== OFIMÁTICA ===" "" off \
    23 "  Abiword + Gnumeric (suite ofimática)" off \
    74 "  LibreOffice (suite ofimática completa)" off \
    24 "  FeatherPad (editor de texto)" off \
    25 "  qpdfview (visor PDF)" off \
    75 "  Wine (ejecutar apps Windows)" off \
    "=== NAVEGADORES ===" "" off \
    26 "  Firefox ESR" off \
    88 "  Firefox (última versión)" off \
    27 "  Tor Browser 15.x" off \
    28 "  Chromium" off \
    90 "  Epiphany (GNOME Web)" off \
    91 "  Falkon (Qt WebEngine)" off \
    92 "  Midori (navegador ligero)" off \
    93 "  Lynx (navegador de texto)" off \
    94 "  qutebrowser (navegadorvim-like)" off \
    "=== MULTIMEDIA ===" "" off \
    29 "  VLC" off \
    30 "  Celluloid" off \
    31 "  Haruna (KDE)" off \
    32 "  Smplayer + MPV" off \
    33 "  Clementine (reproductor de música)" off \
    34 "  Ristretto (visor de imágenes)" off \
    82 "  WinFF (conversor video/audio)" off \
    83 "  SoundConverter (conversor de audio)" off \
    "=== HERRAMIENTAS GRÁFICAS ===" "" off \
    35 "  Flameshot (capturas de pantalla)" off \
    36 "  Arandr (configurar monitores)" off \
    "=== UTILIDADES VARIAS ===" "" off \
    37 "  IPTVnator 0.19" off \
    38 "  Kshutdown (apagar/reniciar)" off \
    39 "  AutoCpufreq (ahorro energía)" off \
    84 "  LXAppearance (temas y apariencia)" off \
    85 "  Nitrogen (gestor de fondos)" off \
    86 "  GDebi (instalador de .deb)" off \
    87 "  Galculator (calculadora científica)" off \
    "=== POST-INSTALL (apps externas) ===" "" off \
    76 "  MetaTrader 5 (trading)" off \
    "=== APAGAR / REINICIAR ===" "" off \
    53 "  Apagar el equipo" off \
    54 "  Reiniciar el equipo" off)

# Comprobar si se ha cancelado la selección
if [ $? -ne 0 ]; then
    echo "Instalación cancelada."
    exit 1
fi

# ============================================================
# PARSING DE OPCIONES DEL MENÚ
# ============================================================
# Dialog devuelve las opciones seleccionadas con formato específico:
# Cada elemento viene entre comillas dobles (ej: "49" o "0")
# Las líneas vacías se filtran

seleccionadas=()

# Reemplazar saltos de línea por espacios, luego procesamiento
opciones_procesadas="${opciones//$'\n'/ }"

# Eliminar comillas dobles
opciones_procesadas="${opciones_procesadas//\"/}"

# Filtrar solo números (las opciones válidas son IDs numéricos)
for opcion in $opciones_procesadas; do
    # Solo agregar si es un número (opción del menú)
    if [[ "$opcion" =~ ^[0-9]+$ ]]; then
        seleccionadas+=("$opcion")
    fi
done

# Debug: mostrar ordenadamente
echo "DEBUG: Opciones seleccionadas: ${seleccionadas[*]}"

# Función para verificar si una opción está seleccionada
esta_seleccionado() {
    local buscar="$1"
    for sel in "${seleccionadas[@]}"; do
        if [[ "$sel" == "$buscar" ]]; then
            return 0
        fi
    done
    return 1
}

# ============================================
# CÓDECS Y DRIVERS (todos de codecs.list sin -dev)
# ============================================
if esta_seleccionado "0"; then
    # Codecs multimedia completos - todos los paquetes disponibles en repos Debian
    echo "Instalando códecs multimedia completos..."

    # --- GStreamer Core y Plugins ---
    sudo nala install -y \
        gstreamer1.0-tools \
        gstreamer1.0-x \
        gstreamer1.0-plugins-base \
        gstreamer1.0-libav \
        gstreamer1.0-plugins-good \
        gstreamer1.0-rtsp \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-opencv \
        gstreamer1.0-fdkaac \
        gstreamer1.0-wpe \
        gstreamer1.0-alsa \
        gstreamer1.0-pulseaudio \
        gstreamer1.0-vaapi \
        gstreamer1.0-gl \
        gstreamer1.0-gtk3 \
        gstreamer1.0-qt5 \
        gstreamer1.0-qt6 \
        gstreamer1.0-libcamera \
        gstreamer1.0-plugins-base-apps \
        gstreamer1.0-plugins-bad-apps \
        gstreamer1.0-pipewire

    # --- FFmpeg / LibAV ---
    # Nota: libavcodec-extra/libavformat-extra/libavfilter-extra excludedos por conflictos
    # en Debian 13. Usar solo ffmpeg que ya incluye los códecs.
    sudo nala install -y \
        ffmpeg

    # --- VA-API Drivers (Hardware Acceleration) ---
    # Solo Intel Gen 8+ (Broadwell en adelante) - el más común y moderno
    # NO instalar i965 (gen≤9) junto con intel-media - son excluyentes
    sudo nala install -y \
        intel-media-va-driver

    # AMD GPU (libre, amdgpu)
    sudo nala install -y \
        mesa-va-drivers

    # VDPAU general
    sudo nala install -y \
        vdpau-driver-all

    # Intel QuickSync (QSV)
    sudo nala install -y \
        libmfx-gen1.2

    # --- Video Codecs ---
    # H.264 / AVC (solo uno - son excluyentes)
    sudo nala install -y \
        libopenh264-8

    # H.265 / HEVC
    sudo nala install -y \
        libkvazaar-dev

    # VP8 / VP9
    sudo nala install -y \
        libvpx-dev

    # AV1 (Alliance for Open Media)
    sudo nala install -y \
        libaom-dev \
        libdav1d-dev \
        librav1e-dev \
        libsvtav1enc-dev

    # --- Audio Codecs ---
    sudo nala install -y \
        libopus0 \
        libvorbis0a \
        libvorbisenc2 \
        libmp3lame0 \
        libflac14 \
        libfaad2 \
        libspeex1 \
        libtwolame0 \
        libgsm1 \
        libjxl0.11 \
        libwavpack1 \
        libxvidcore4

    # --- Codecs de imagen ---
    sudo nala install -y \
        libjpeg62 \
        libwebp7 \
        libpng16-16t64 \
        libtiff6

    # --- Containers / Muxers / Demuxers ---
    sudo nala install -y \
        mkvtoolnix-gui \
        mkvtoolnix

    # --- Efectos y filtros ---
    sudo nala install -y \
        frei0r-plugins

    # --- Herramientas de audio/video ---
    sudo nala install -y \
        vorbis-tools \
        flac \
        sox \
        lame \
        faad \
        mencoder \
        twolame \
        x264 \
        x265 \
        vpx-tools \
        sound-icons \
        mp3gain \
        ffmpegthumbs \
        ffmpegthumbnailer

    # --- Soporte para DVDs (libdvdcss2) ---
    sudo nala install -y libdvd-pkg
    sudo dpkg-reconfigure -p critical libdvd-pkg 2>/dev/null || true

    installed_apps+=("Codecs Multimedia Globales")
fi

# ============================================
# CÓDECS NVIDIA (Hardware Acceleration)
# ============================================
if esta_seleccionado "99"; then
    # Codecs específicos para GPU NVIDIA
    echo "Instalando códecs NVIDIA..."

    # VA-API driver para NVIDIA
    sudo nala install -y \
        nvidia-vaapi-driver

    # VDPAU driver para NVIDIA
    sudo nala install -y \
        nvidia-vdpau-driver

    # NVIDIA NVENC (hardware encoding) / NVDEC (hardware decoding)
    # Requiere driver propietario nvidia-*
    sudo nala install -y \
        libnvidia-encode1 \
        libnvcuvid1

    # Nota: Los códecs nvenc específicos (libx264-nvenc-760, libx265-nvenc-760)
    # no están disponibles en repos Debian. Se instalan automáticamente con el
    # driver propietario de NVIDIA.

    installed_apps+=("Codecs NVIDIA")
fi

if esta_seleccionado "1"; then
    # Firmware completo para todo hardware out-of-the-box
    echo "Instalando firmware..."
    
    # Firmware principal (libre + no libre)
    sudo nala install -y \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-realtek \
        firmware-iwlwifi \
        firmware-atheros \
        firmware-ath9k-htc \
        firmware-ath6kl \
        firmware-bnx2 \
        firmware-bnx2x \
        firmware-brcm80211 \
        firmware-cavium \
        firmware-intel-sound \
        firmware-intel-spi \
        firmware-ipw2x00 \
        firmware-ivtv \
        firmware-libertas \
        firmware-myricom \
        firmware-netxen \
        firmware-qlogic \
        firmware-samsung \
        firmware-siano \
        firmware-ti-connectivity \
        firmware-zd1211
    
    # Microcode para CPU (importante para seguridad y rendimiento)
    sudo nala install -y amd64-microcode || sudo nala install -y intel-microcode || true
    
    # Firmware específico para gráficos (si hay GPU dedicada)
    sudo nala install -y firmware-amd-graphics || true
    
    installed_apps+=("Firmware Linux (completo)")
fi

if esta_seleccionado "2"; then
    # Drivers de gráficos completos
    echo "Instalando Xorg básico..."
    
    # Xorg base + drivers genéricos
    sudo nala install -y \
        xorg \
        xserver-xorg-core \
        xserver-xorg-video-all \
        xserver-xorg-video-fbdev \
        xserver-xorg-video-vesa \
        xserver-xorg-video-vmware
    
    # Mesa (OpenGL) - básico para todos
    sudo nala install -y \
        libgl1-mesa-dri \
        libgl1-mesa-glx \
        mesa-vulkan-drivers \
        mesa-utils
    
    # VA-API base (aceleración de video por hardware)
    sudo nala install -y \
        libva-drm2 \
        libva-glx2 \
        libva-wayland2 \
        libva-x11-2 \
        libva2 \
        va-driver-all
    
    # Compton/compositor para efectos
    sudo nala install -y picom || true
    
    installed_apps+=("Xorg básico")
fi

# ============================================
# DRIVERS INTEL
# ============================================
if esta_seleccionado "95"; then
    echo "Instalando drivers Intel..."
    
    # Drivers de video Intel
    sudo nala install -y \
        xserver-xorg-video-intel \
        intel-media-va-driver \
        i965-va-driver \
        intel-gpu-tools
    
    # OpenCL para Intel (si se necesita)
    sudo nala install -y mesa-opencl-icd || true
    
    # Herramientas de verificación
    sudo nala install -y \
        radeontop \
        mesa-utils-bin
    
    installed_apps+=("Drivers Intel")
fi

# ============================================
# DRIVERS NVIDIA
# ============================================
if esta_seleccionado "96"; then
    echo "Instalando drivers NVIDIA..."
    
    # Habilitar arquitectura i386 para algunos paquetes
    sudo dpkg --add-architecture i386 2>/dev/null || true
    sudo nala update
    
    # Driver propietario NVIDIA
    sudo nala install -y \
        nvidia-driver \
        nvidia-driver-libs \
        nvidia-settings \
        nvidia-suspend \
        nvidia-powerd \
        nvidia-kernel-dkms \
        nvidia-kernel-support
    
    # Drivers de Xorg NVIDIA
    sudo nala install -y \
        xserver-xorg-video-nvidia-525 \
        xserver-xorg-video-nvidia-535 \
        xserver-xorg-video-nvidia-545
    
    # CUDA y herramientas de desarrollo GPU
    sudo nala install -y \
        nvidia-cuda-toolkit \
        nvidia-cuda-dev \
        cuda-toolkit-12 || true
    
    # OpenCL para NVIDIA
    sudo nala install -y \
        ocl-icd-libopencl1 \
        ocl-icd-opencl-dev \
        opencl-headers || true
    
    #驱动层 (VK)
    sudo nala install -y \
        libvulkan1 \
        vulkan-tools \
        vulkan-validationlayers || true
    
    # Herramientas de verificación
    sudo nala install -y nvidia-smi
    
    # Reiniciar servicio gráfico para aplicar cambios
    echo "Nota: Los drivers NVIDIA requieren reiniciar el sistema para activarse"
    
    installed_apps+=("Drivers NVIDIA (proprietario)")
fi

# ============================================
# WAYLAND BÁSICO
# ============================================
if esta_seleccionado "97"; then
    echo "Instalando Wayland básico..."
    
    # Wayland mínimo indispensable (igual que Xorg básico)
    sudo nala install -y \
        wayland \
        weston \
        wayland-protocols \
        libwayland-dev \
        libwayland-egl1 \
        libwayland-cursor0 \
        libwayland-bin \
        libwlroots12 \
        xwayland \
        egl-wayland \
        libva-wayland2 \
        libdrm2 \
        mesa-vulkan-drivers
    
    # Paquetes de soporte para desktops que usan Wayland (GNOME/KDE)
    sudo nala install -y \
        gnome-shell \
        mutter \
        kwayland \
        kwin-wayland || true
    
    installed_apps+=("Wayland básico")
fi

# ============================================
# WAYLAND TOOLS (Compositors y herramientas)
# ============================================
if esta_seleccionado "98"; then
    echo "Instalando herramientas Wayland..."
    
    # Compositors (window managers para Wayland)
    sudo nala install -y \
        sway \
        labwc \
        river \
        cage \
        niri \
        kwayland \
        weston
    
    # Herramientas del sistema
    sudo nala install -y \
        wayland-utils \
        libinput-tools \
        libseat-tools \
        seatd
    
    # Menús y launchers
    sudo nala install -y \
        bemenu \
        wofi \
        albert
    
    # Captura de pantalla y screencast
    sudo nala install -y \
        grim \
        slurp \
        wl-clipboard \
        wf-recorder \
        obs-studio
    
    # Notificaciones y system tray
    sudo nala install -y \
        mako \
        swaynotificationcenter \
        dunst
    
    # Lock y idle
    sudo nala install -y \
        swaylock \
        swayidle \
        wlogout \
        betterlockscreen
    
    # Wallpaper y theming
    sudo nala install -y \
        swaybg \
        nitrogen \
        swaybg
    
    # Barras de estado
    sudo nala install -y \
        waybar \
        yambar \
        wldash \
        lemonbar
    
    # Misc tools
    sudo nala install -y \
        wlr-randr \
        kanshi \
        gammastep \
        autotiling
    
    # Soporte para apps Qt en Wayland
    sudo nala install -y \
        qt6-wayland \
        qtwayland \
        layer-shell-qt
    
    installed_apps+=("Wayland Tools (sway, labwc, river, etc)")
fi

# ============================================
# GESTIÓN DE DISCOS
# ============================================
if esta_seleccionado "3"; then
    sudo nala install -y gparted
    installed_apps+=("GParted")
fi

if esta_seleccionado "4"; then
    sudo nala install -y ntfs-3g
    installed_apps+=("NTFS-3g")
fi

if esta_seleccionado "5"; then
    sudo nala install -y exfat-fuse
    installed_apps+=("Exfat-fuse")
fi

if esta_seleccionado "77"; then
    sudo nala install -y gnome-disk-utility
    installed_apps+=("GNOME Disk Utility")
fi

if esta_seleccionado "78"; then
    sudo nala install -y smartmontools smart-notifier
    installed_apps+=("SMART Montools")
fi

# ============================================
# RED Y CONECTIVIDAD
# ============================================
if esta_seleccionado "6"; then
    sudo nala install -y network-manager network-manager-gnome
    installed_apps+=("Network Manager")
fi

if esta_seleccionado "72"; then
    sudo nala install -y connman connman-gtk
    installed_apps+=("ConnMan")
fi

if esta_seleccionado "7"; then
    sudo nala install -y openvpn network-manager-openvpn network-manager-openvpn-gnome
    installed_apps+=("OpenVPN")
fi

if esta_seleccionado "8"; then
    sudo nala install -y mtp-tools libmtp-runtime
    installed_apps+=("MTP-tools (Android)")
fi

if esta_seleccionado "9"; then
    sudo nala install -y ifuse libimobiledevice6 libimobiledevice-utils usbmuxd
    installed_apps+=("iPhone/iPad support")
fi

# ============================================
# SISTEMA
# ============================================
if esta_seleccionado "10"; then
    sudo nala update && sudo apt full-upgrade -y
    installed_apps+=("Sistema Actualizado")
fi

if esta_seleccionado "79"; then
    sudo nala install -y hardinfo2
    installed_apps+=("HardInfo2")
fi

if esta_seleccionado "80"; then
    sudo nala install -y grub-customizer
    installed_apps+=("GRUB Customizer")
fi

if esta_seleccionado "81"; then
    sudo nala install -y zram-tools preload
    installed_apps+=("ZRAM Tools + Preload")
fi

# ============================================
# GESTOR DE SESIÓN
# ============================================
if esta_seleccionado "11"; then
    sudo nala install -y lightdm lightdm-gtk-greeter
    sudo systemctl set-default graphical.target
    installed_apps+=("LightDM")
fi

if esta_seleccionado "12"; then
    sudo nala install -y sddm
    sudo systemctl set-default graphical.target
    installed_apps+=("SDDM")
fi

# ============================================
# ESCRITORIOS
# ============================================
if esta_seleccionado "41"; then
    sudo nala install -y lxde lxde-common lxterminal pcmanfm openbox
    sudo systemctl set-default graphical.target
    installed_apps+=("LXDE")
fi

if esta_seleccionado "42"; then
    sudo nala install -y lxqt lxqt-sudo pcmanfm-qt openbox
    sudo systemctl set-default graphical.target
    installed_apps+=("LXQt")
fi

if esta_seleccionado "57"; then
    sudo nala install -y xfce4 xfce4-goodies thunar thunar-volman
    sudo systemctl set-default graphical.target
    installed_apps+=("XFCE")
fi

if esta_seleccionado "43"; then
    sudo nala install -y mate mate-desktop-environment-core
    sudo systemctl set-default graphical.target
    installed_apps+=("MATE")
fi

if esta_seleccionado "44"; then
    sudo nala install -y cinnamon cinnamon-desktop-environment
    sudo systemctl set-default graphical.target
    installed_apps+=("Cinnamon")
fi

if esta_seleccionado "45"; then
    sudo nala install -y gnome gnome-shell gnome-session gnome-terminal
    sudo systemctl set-default graphical.target
    installed_apps+=("GNOME")
fi

if esta_seleccionado "46"; then
    sudo nala install -y kde-plasma-desktop
    sudo systemctl set-default graphical.target
    installed_apps+=("KDE Plasma")
fi

# ============================================
# WINDOW MANAGERS - i3-wm
# ============================================
if esta_seleccionado "48"; then
    # Instalar dependencias del sistema
    sudo apt update
    sudo nala install -y \
        i3-wm \
        i3status \
        i3lock \
        xss-lock \
        dex \
        nitrogen \
        rofi \
        lxterminal \
        network-manager-gnome \
        volumeicon-alsa \
        udiskie \
        fonts-powerline \
        fonts-font-awesome \
        libpam-systemd \
        x11-xserver-utils

    # Copiar configs de i3 desde los archivos locales
    USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
    mkdir -p "$USER_HOME/.config/i3"
    cp "./i3 configuration/i3/config" "$USER_HOME/.config/i3/config"
    
    # Copiar script de iconos si existe
    if [ -f "./i3 configuration/i3/i3-title-icons.py" ]; then
        cp "./i3 configuration/i3/i3-title-icons.py" "$USER_HOME/.config/i3/i3-title-icons.py"
    fi

    # Copiar config de i3status
    mkdir -p "$USER_HOME/.config/i3status"
    cp "./i3 configuration/i3status/config" "$USER_HOME/.config/i3status/config"

    # Asegurar que el locale es_ES.UTF-8 esté instalado
    if ! locale -a | grep -q "es_ES.utf8"; then
        sudo sed -i '/es_ES.UTF-8/s/^# //g' /etc/locale.gen 2>/dev/null || true
        sudo locale-gen es_ES.UTF-8 2>/dev/null || sudo nala install -y locales && sudo sed -i '/es_ES.UTF-8/s/^# //g' /etc/locale.gen && sudo locale-gen es_ES.UTF-8
    fi

    # Dar permisos al usuario
    OWNER_USER=${SUDO_USER:-$USER}
    chown -R "$OWNER_USER:$OWNER_USER" "$USER_HOME/.config/i3"
    chown -R "$OWNER_USER:$OWNER_USER" "$USER_HOME/.config/i3status"

    sudo systemctl set-default graphical.target
    installed_apps+=("i3-wm")
fi

# ============================================
# WINDOW MANAGERS - IceWM
# ============================================
if esta_seleccionado "49"; then
    # Instalar IceWM y todas las dependencias del startup
    sudo nala install -y \
        icewm \
        icewm-common \
        volumeicon-alsa \
        udiskie \
        lxpolkit \
        network-manager-gnome \
        nitrogen \
        rofi \
        lxterminal \
        libpam-systemd \
        x11-xserver-utils \
        menu \
        wmctrl \
        trayer

    # Instalar LightDM si no hay gestor de sesión gráfico
    if ! command -v lightdm &> /dev/null && ! command -v sddm &> /dev/null; then
        echo "No se detectó gestor de sesión. Instalando LightDM..."
        sudo nala install -y lightdm lightdm-gtk-greeter
    fi

    # Copiar configs de IceWM desde los archivos locales
    USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
    mkdir -p "$USER_HOME/.icewm"

    # Copiar archivos de configuración
    cp "./icewm configuration/preferences" "$USER_HOME/.icewm/preferences"
    cp "./icewm configuration/prefoverride" "$USER_HOME/.icewm/prefoverride"
    cp "./icewm configuration/startup" "$USER_HOME/.icewm/startup"
    
    # Copiar theme si existe (es un archivo, no un directorio)
    if [ -f "./icewm configuration/theme" ]; then
        cp "./icewm configuration/theme" "$USER_HOME/.icewm/theme"
    fi

    # Primero cambiar Dueño, luego dar permisos de ejecución
    OWNER_USER=${SUDO_USER:-$USER}
    chown -R "$OWNER_USER:$OWNER_USER" "$USER_HOME/.icewm"
    chmod +x "$USER_HOME/.icewm/startup"

    sudo systemctl set-default graphical.target
    installed_apps+=("IceWM")
fi

# ============================================
# AUDIO
# ============================================
if esta_seleccionado "13"; then
    sudo nala install -y pulseaudio pavucontrol
    installed_apps+=("PulseAudio + Pavucontrol")
fi

if esta_seleccionado "89"; then
    # PipeWire - servidor de audio moderno
    echo "Instalando PipeWire y componentes..."
    
    # Instalar PipeWire y componentes
    sudo nala install -y \
        pipewire \
        pipewire-pulse \
        pipewire-alsa \
        pipewire-bin \
        wireplumber \
        libpipewire-0.3-modules \
        libpipewire-0.3-common \
        gstreamer1.0-pipewire \
        pw-dot \
        pavucontrol \
        qpwgraph
    
    # Habilitar servicios de PipeWire
    systemctl --user enable pipewire.service 2>/dev/null || true
    systemctl --user enable pipewire-pulse.service 2>/dev/null || true
    systemctl --user enable wireplumber.service 2>/dev/null || true
    
    # Configurar como sistema de audio por defecto
    sudo tee /etc/pulse/client.conf.d/99-pipewire.conf > /dev/null << 'EOF'
autospawn = yes
EOF
    
    # Crear config de PipeWire si no existe
    USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
    mkdir -p "$USER_HOME/.config/pipewire/pipewire.conf.d"
    
    # Copiar configs de ejemplo si existen
    if [ -d /usr/share/pipewire ]; then
        cp -r /usr/share/pipewire/*.conf "$USER_HOME/.config/pipewire/" 2>/dev/null || true
    fi
    
    # Dar permisos
    OWNER_USER=${SUDO_USER:-$USER}
    chown -R "$OWNER_USER:$OWNER_USER" "$USER_HOME/.config/pipewire" 2>/dev/null || true
    
    installed_apps+=("PipeWire + Pavucontrol")
fi

if esta_seleccionado "14"; then
    sudo nala install -y alsa-utils
    installed_apps+=("Alsa-utils")
fi

# ============================================
# SEGURIDAD
# ============================================
if esta_seleccionado "15"; then
    sudo nala install -y ufw gufw
    sudo ufw enable
    installed_apps+=("UFW + GUFW")
fi

if esta_seleccionado "16"; then
    sudo nala install -y clamav clamtk
    installed_apps+=("ClamAV + ClamTK")
fi

if esta_seleccionado "17"; then
    sudo nala install -y bleachbit
    installed_apps+=("BleachBit")
fi

# ============================================
# DESARROLLO
# ============================================
if esta_seleccionado "18"; then
    sudo nala install -y build-essential make automake cmake autoconf
    installed_apps+=("Build-essential")
fi

if esta_seleccionado "19"; then
    sudo nala install -y git
    installed_apps+=("Git")
fi

if esta_seleccionado "20"; then
    sudo nala install -y fastfetch
    installed_apps+=("Fastfetch")
fi

if esta_seleccionado "70"; then
    sudo nala install -y htop
    installed_apps+=("htop")
fi

if esta_seleccionado "71"; then
    sudo nala install -y btop
    installed_apps+=("btop")
fi

# ============================================
# COMPRESIÓN Y ARCHIVOS
# ============================================
if esta_seleccionado "21"; then
    # Descompresores completos
    sudo nala install -y \
        p7zip-full \
        rar \
        unrar \
        unace \
        lzip \
        arj \
        sharutils \
        mpack \
        lzma \
        lzop \
        unzip \
        zip \
        bzip2 \
        lhasa \
        cabextract \
        lrzip \
        rzip \
        zpaq \
        kgb \
        xz-utils \
        xarchiver
    installed_apps+=("Herramientas de compresión")
fi

# ============================================
# FILE MANAGERS
# ============================================
if esta_seleccionado "22"; then
    sudo nala install -y doublecmd-gtk
    installed_apps+=("Double Commander")
fi

if esta_seleccionado "50"; then
    sudo nala install -y pcmanfm
    installed_apps+=("PCManFM")
fi

if esta_seleccionado "51"; then
    sudo nala install -y pcmanfm-qt
    installed_apps+=("PCManFM-Qt")
fi

if esta_seleccionado "55"; then
    sudo nala install -y thunar thunar-volman
    installed_apps+=("Thunar")
fi

if esta_seleccionado "56"; then
    sudo nala install -y krusader
    installed_apps+=("Krusader")
fi

# ============================================
# TERMINALES Y SHELLS
# ============================================
if esta_seleccionado "58"; then
    sudo nala install -y lxterminal
    installed_apps+=("LXTerminal")
fi

if esta_seleccionado "59"; then
    sudo nala install -y kitty kitty-terminfo
    installed_apps+=("Kitty")
fi

if esta_seleccionado "60"; then
    sudo nala install -y alacritty
    installed_apps+=("Alacritty")
fi

if esta_seleccionado "61"; then
    sudo nala install -y sakura
    installed_apps+=("Sakura")
fi

if esta_seleccionado "62"; then
    sudo nala install -y xfce4-terminal
    installed_apps+=("XFCE4 Terminal")
fi

if esta_seleccionado "63"; then
    sudo nala install -y tilix
    installed_apps+=("Tilix")
fi

if esta_seleccionado "64"; then
    sudo nala install -y terminator
    installed_apps+=("Terminator")
fi

if esta_seleccionado "65"; then
    sudo nala install -y terminology
    installed_apps+=("Terminology")
fi

if esta_seleccionado "66"; then
    sudo nala install -y rxvt-unicode
    installed_apps+=("URxvt")
fi

if esta_seleccionado "67"; then
    sudo nala install -y stterm
    installed_apps+=("St")
fi

if esta_seleccionado "68"; then
    sudo nala install -y fish fish-common
    installed_apps+=("Fish")
fi

if esta_seleccionado "69"; then
    sudo nala install -y zsh zsh-syntax-highlighting zsh-autosuggestions
    installed_apps+=("Zsh + plugins")
fi

if esta_seleccionado "73"; then
    sudo nala install -y zoxide
    installed_apps+=("Zoxide")
fi

# ============================================
# OFIMÁTICA
# ============================================
if esta_seleccionado "23"; then
    sudo nala install -y abiword gnumeric
    installed_apps+=("Abiword + Gnumeric")
fi

if esta_seleccionado "74"; then
    # Instalar LibreOffice completo desde repositorios oficiais
    sudo nala install -y libreoffice libreoffice-writer libreoffice-calc libreoffice-impress \
        libreoffice-draw libreoffice-math libreoffice-base libreoffice-l10n-es \
        libreoffice-gnome libreoffice-gtk3 libreoffice-help-es
    installed_apps+=("LibreOffice")
fi

if esta_seleccionado "75"; then
    # Habilitar arquitectura i386 para Wine
    sudo dpkg --add-architecture i386
    sudo nala update
    # Instalar Wine
    sudo nala install -y wine wine64 wine32 winetricks
    installed_apps+=("Wine")
fi

if esta_seleccionado "24"; then
    sudo nala install -y featherpad
    installed_apps+=("FeatherPad")
fi

if esta_seleccionado "25"; then
sudo nala install -y qpdfview
            installed_apps+=("qpdfview")
fi

# ============================================
# NAVEGADORES
# ============================================
for opcion in "${seleccionadas[@]}"; do
    case $opcion in
        26)
            sudo nala install -y firefox-esr
            installed_apps+=("Firefox ESR")
            ;;
        88)
            # Firefox normal - desde repositorio Debian
            echo "Instalando Firefox (última versión)..."
            # Añadir repositorio de Firefox Mozilla
            echo 'deb http://mozilla.debian.net/ trixie main' | sudo tee /etc/apt/sources.list.d/mozilla.list
            wget -q https://mozilla.debian.net/archive.asc -O- | sudo tee /etc/apt/trusted.gpg.d/mozilla.asc
            sudo nala update
            sudo nala install -y firefox firefox-l10n-es
            installed_apps+=("Firefox (última versión)")
            ;;
        27)
            cd /tmp
            axel -a -o tor-browser-15.0.8.tar.xz https://www.torproject.org/dist/torbrowser/15.0.8/tor-browser-linux-x86_64-15.0.8.tar.xz
            tar -xf tor-browser-15.0.8.tar.xz
            sudo mv tor-browser /opt/tor-browser
            rm -f tor-browser-15.0.8.tar.xz
            installed_apps+=("Tor Browser 15.0.8")
            ;;
        28)
            sudo nala install -y chromium chromium-l10n
            installed_apps+=("Chromium")
            ;;
        90)
            # Epiphany (GNOME Web)
            sudo nala install -y epiphany-browser
            installed_apps+=("Epiphany (GNOME Web)")
            ;;
        91)
            # Falkon (Qt WebEngine)
            sudo nala install -y falkon
            installed_apps+=("Falkon")
            ;;
        92)
            # Midori
            sudo nala install -y midori
            installed_apps+=("Midori")
            ;;
        93)
            # Lynx (navegador de texto)
            sudo nala install -y lynx
            installed_apps+=("Lynx (texto)")
            ;;
        94)
            # qutebrowser
            sudo nala install -y qutebrowser qutebrowser-qtutils
            installed_apps+=("qutebrowser")
            ;;
    esac
done

# ============================================
# MULTIMEDIA
# ============================================
for opcion in "${seleccionadas[@]}"; do
    case $opcion in
        29)
            sudo nala install -y vlc
            installed_apps+=("VLC")
            ;;
        30)
            sudo nala install -y celluloid
            installed_apps+=("Celluloid")
            ;;
        31)
            sudo nala install -y haruna
            installed_apps+=("Haruna")
            ;;
        32)
            sudo nala install -y smplayer smplayer-l10n mpv libva-dev libvdpau-dev
            installed_apps+=("Smplayer + MPV")
            # Configurar aceleración por hardware en MPV
            USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
            mkdir -p "$USER_HOME/.config/mpv"
            if [ ! -f "$USER_HOME/.config/mpv/mpv.conf" ]; then
                touch "$USER_HOME/.config/mpv/mpv.conf"
            fi
            if ! grep -q "hwdec=auto" "$USER_HOME/.config/mpv/mpv.conf" 2>/dev/null; then
                echo "hwdec=auto" >> "$USER_HOME/.config/mpv/mpv.conf"
            fi
            if ! grep -q "vo=gpu" "$USER_HOME/.config/mpv/mpv.conf" 2>/dev/null; then
                echo "vo=gpu" >> "$USER_HOME/.config/mpv/mpv.conf"
            fi
            OWNER_USER=${SUDO_USER:-$USER}
            chown -R "$OWNER_USER:$OWNER_USER" "$USER_HOME/.config/mpv"
            ;;
        33)
            sudo nala install -y clementine
            installed_apps+=("Clementine")
            ;;
        34)
            sudo nala install -y ristretto
            installed_apps+=("Ristretto")
            ;;
        82)
            sudo nala install -y winff winff-qt
            installed_apps+=("WinFF")
            ;;
        83)
            sudo nala install -y soundconverter
            installed_apps+=("SoundConverter")
            ;;
    esac
done

# ============================================
# HERRAMIENTAS GRÁFICAS
# ============================================
for opcion in "${seleccionadas[@]}"; do
    case $opcion in
        35)
            sudo nala install -y flameshot
            installed_apps+=("Flameshot")
            ;;
        36)
            sudo nala install -y arandr
            installed_apps+=("Arandr")
            ;;
    esac
done

# ============================================
# UTILIDADES VARIAS
# ============================================
for opcion in "${seleccionadas[@]}"; do
    case $opcion in
        37)
            cd /tmp
            axel -a -o iptvnator-0.19.0-linux-amd64.deb https://github.com/4gray/iptvnator/releases/download/v0.19.0/iptvnator-0.19.0-linux-amd64.deb
            sudo dpkg -i iptvnator-0.19.0-linux-amd64.deb
            rm -f iptvnator-0.19.0-linux-amd64.deb
            sudo nala install -f
            cd - > /dev/null
            installed_apps+=("IPTVnator 0.19.0")
            ;;
        38)
            sudo nala install -y kshutdown
            installed_apps+=("Kshutdown")
            ;;
        39)
            cd /tmp
            git clone https://github.com/AdnanHodzic/auto-cpufreq.git
            cd auto-cpufreq
            sudo bash auto-cpufreq-installer -y << EOF
I
EOF
            cd /tmp && rm -rf auto-cpufreq
            cd - > /dev/null
            installed_apps+=("AutoCpufreq")
            ;;
        84)
            sudo nala install -y lxappearance
            installed_apps+=("LXAppearance")
            ;;
        85)
            sudo nala install -y nitrogen
            installed_apps+=("Nitrogen")
            ;;
        86)
            sudo nala install -y gdebi
            installed_apps+=("GDebi")
            ;;
        87)
            sudo nala install -y galculator
            installed_apps+=("Galculator")
            ;;
        76)
            # MetaTrader 5 - descarga e instala desde script oficial
            cd /tmp
            wget -O mt5linux.sh https://download.terminal.free/cdn/web/metaquotes.software.corp/mt5/mt5linux.sh
            chmod +x mt5linux.sh
            ./mt5linux.sh
            rm -f mt5linux.sh
            cd - > /dev/null
            installed_apps+=("MetaTrader 5")
            ;;
        53)
            # Apagar - verificar que no esté seleccionada también la opción de reiniciar
            if esta_seleccionado "54"; then
                echo "ERROR: No se puede apagar y reiniciar al mismo tiempo. Ignorando..."
            else
                sudo shutdown -h now
            fi
            ;;
        54)
            # Reiniciar - verificar que no esté seleccionada también la opción de apagar
            if esta_seleccionado "53"; then
                echo "ERROR: No se puede apagar y reiniciar al mismo tiempo. Ignorando..."
            else
                sudo shutdown -r now
            fi
            ;;
    esac
done

# Log final
log_file="$HOME/resumen_instalacion.txt"
end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo "" >> "$log_file"
echo "Tiempo total de ejecución: $((execution_time / 60)) minutos y $((execution_time % 60)) segundos." >> "$log_file"
internet_speed=$(curl -s -w %{speed_download} -o /dev/null http://example.com)
echo "Velocidad de conexión a internet: $internet_speed MB/seg" >> "$log_file"

# Corregir permisos si se ejecutaron como root
fix_permissions

# Mostrar resumen final
echo ""
echo "==========================================="
echo "INSTALACIÓN COMPLETADA"
echo "==========================================="
echo "Aplicaciones instaladas:"
for app in "${installed_apps[@]}"; do
    echo "  - $app"
done
echo "==========================================="
echo ""
echo "NOTA: Si ejecutaste con 'su -c', haz logout y login para que los permisos de sudo tengan efecto."