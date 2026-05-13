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
    
    # Verificar si el usuario ya está configurado (en sudoers o sudoers.d)
    if grep -q \"^${CURRENT_USER} \" /etc/sudoers 2>/dev/null || [ -f /etc/sudoers.d/${CURRENT_USER} ]; then
        echo \"sudo ya está configurado para $CURRENT_USER\"
    else
        echo \"Configurando sudoers para $CURRENT_USER...\"
        # Usar /etc/sudoers.d/ (práctica recomendada en Debian)
        echo \"${CURRENT_USER} ALL=(ALL:ALL) ALL\" > /etc/sudoers.d/${CURRENT_USER}
        chmod 440 /etc/sudoers.d/${CURRENT_USER}
        echo \"sudo configurado correctamente para $CURRENT_USER\"
    fi
"