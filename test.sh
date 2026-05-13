# Cambiar a root para hacer toda la configuración de sudo
su -c "
    set -e
    
    # Detectar si sudo está instalado
    if ! command -v sudo &> /dev/null; then
        echo \"sudo no está instalado. Instalando...\"
        echo \"Configurando repositorios de Debian Trixie...\"
        cat > /etc/apt/sources.list << EOF
deb https://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
EOF
        apt update && apt install -y sudo
        echo \"sudo instalado correctamente\"
    else
        echo \"sudo ya está instalado\"
    fi
    
    echo \"\"
    echo \"Verificando configuración de sudo para $CURRENT_USER...\"
    
    # Verificar si el usuario está en /etc/sudoers
    if ! grep -q \"^${CURRENT_USER} \" /etc/sudoers; then
        echo \"Configurando sudoers para $CURRENT_USER...\"
        # Buscar la línea \"root ALL=(ALL:ALL) ALL\" y escribir debajo la del usuario
         sed -i \"/^root ALL=\(ALL:ALL\) ALL\$/a ${CURRENT_USER} ALL=(ALL:ALL) ALL\" /etc/sudoers
        echo \"sudo configurado correctamente para $CURRENT_USER\"
    else
        echo \"sudo ya está configurado para $CURRENT_USER\"
    fi
"