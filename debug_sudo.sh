#!/bin/bash

# ============================================
# SCRIPT DE DEBUG PARA CONFIGURACIÓN DE SUDO
# ============================================

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║          DEBUG - Configuración de SUDO                   ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ============================================
# PASO 1: Detectar si sudo está instalado
# ============================================
echo "[1] Verificando si sudo está instalado..."
if command -v sudo &> /dev/null; then
    echo "    ✓ sudo ENCONTRADO en el sistema"
    SUDO_INSTALLED=true
else
    echo "    ✗ sudo NO ENCONTRADO en el sistema"
    SUDO_INSTALLED=false
fi
echo ""

# ============================================
# PASO 2: Si sudo NO está instalado, instalarlo
# ============================================
if [ "$SUDO_INSTALLED" = false ]; then
    echo "[2] sudo no está instalado. Instalando..."
    echo "    Cambiando a root con 'su -c'..."
    
    su -c '
        echo "    [2.1] Dentro del contexto de root"
        
        echo "    [2.2] Configurando repositorios de Debian Trixie..."
        cat > /etc/apt/sources.list << EOF
deb https://deb.debian.org/debian/ trixie main contrib non-free non-free-firmware
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ trixie-updates main contrib non-free non-free-firmware
EOF
        
        if [ $? -eq 0 ]; then
            echo "    ✓ Repositorios configurados correctamente"
        else
            echo "    ✗ Error al configurar repositorios"
            exit 1
        fi
        
        echo "    [2.3] Actualizando índice de paquetes..."
        apt update
        
        if [ $? -eq 0 ]; then
            echo "    ✓ Índice actualizado"
        else
            echo "    ✗ Error al actualizar índice"
            exit 1
        fi
        
        echo "    [2.4] Instalando sudo..."
        apt install -y sudo
        
        if [ $? -eq 0 ]; then
            echo "    ✓ sudo instalado correctamente"
        else
            echo "    ✗ Error al instalar sudo"
            exit 1
        fi
        
        echo "    [2.5] Obteniendo usuario actual..."
        CURRENT_USER=$(logname)
        echo "    Usuario actual: $CURRENT_USER"
        
        if [ -z "$CURRENT_USER" ]; then
            echo "    ✗ No se pudo obtener el usuario actual"
            exit 1
        fi
        
        echo "    ✓ Usuario identificado: $CURRENT_USER"
    '
    
    if [ $? -eq 0 ]; then
        echo "    ✓ Instalación de sudo completada exitosamente"
    else
        echo "    ✗ Error durante la instalación de sudo"
        exit 1
    fi
else
    echo "[2] sudo ya está instalado, omitiendo instalación"
fi
echo ""

# ============================================
# PASO 3: Verificar configuración de sudo
# ============================================
echo "[3] Verificando configuración de sudo..."

# Obtener usuario actual
CURRENT_USER=$(logname)
echo "    Usuario actual: $CURRENT_USER"

if [ -z "$CURRENT_USER" ]; then
    echo "    ✗ No se pudo obtener el usuario actual"
    exit 1
fi

# Verificar si /etc/sudoers existe
echo "    [3.1] Verificando si /etc/sudoers existe..."
if [ -f /etc/sudoers ]; then
    echo "    ✓ /etc/sudoers existe"
else
    echo "    ✗ /etc/sudoers NO EXISTE"
    exit 1
fi
echo ""

# Verificar si el usuario ya está en sudoers
echo "    [3.2] Verificando si el usuario está en /etc/sudoers..."
if grep -q "^${CURRENT_USER} " /etc/sudoers 2>/dev/null; then
    echo "    ✓ Usuario ya está configurado en sudoers"
    echo ""
    echo "    Contenido actual de sudoers para este usuario:"
    grep "^${CURRENT_USER}" /etc/sudoers | sed 's/^/        /'
else
    echo "    ✗ Usuario NO está en sudoers"
    echo ""
    echo "    [3.3] Buscando la línea 'root ALL=(ALL:ALL) ALL'..."
    
    if grep -q "^root ALL=(ALL:ALL) ALL$" /etc/sudoers 2>/dev/null; then
        echo "    ✓ Línea de root encontrada"
        echo ""
        echo "    [3.4] Agregando usuario a sudoers..."
        
        # Crear backup
        echo "    [3.4.1] Creando backup de /etc/sudoers..."
        cp /etc/sudoers /etc/sudoers.backup
        echo "    ✓ Backup creado en /etc/sudoers.backup"
        
        # Cambiar a root para modificar sudoers
        su -c "
            echo \"    [3.4.2] Dentro del contexto de root modificando sudoers...\"
            
            # Verificar nuevamente que no esté
            if ! grep -q \"^${CURRENT_USER} \" /etc/sudoers; then
                echo \"    [3.4.3] Insertando línea para ${CURRENT_USER}...\"
                sed -i \"/^root ALL=(ALL:ALL) ALL\$/a ${CURRENT_USER} ALL=(ALL:ALL) ALL\n\" /etc/sudoers
                
                if [ \$? -eq 0 ]; then
                    echo \"    ✓ Línea insertada correctamente\"
                else
                    echo \"    ✗ Error al insertar línea\"
                    exit 1
                fi
            else
                echo \"    Usuario ya estaba en sudoers\"
            fi
        "
        
        if [ $? -eq 0 ]; then
            echo "    ✓ sudoers modificado correctamente"
        else
            echo "    ✗ Error al modificar sudoers"
            echo "    Restaurando backup..."
            su -c "cp /etc/sudoers.backup /etc/sudoers"
            exit 1
        fi
    else
        echo "    ✗ Línea 'root ALL=(ALL:ALL) ALL' NO encontrada"
        echo ""
        echo "    Contenido actual de /etc/sudoers (primeras líneas):"
        head -10 /etc/sudoers | sed 's/^/        /'
        exit 1
    fi
fi
echo ""

# ============================================
# PASO 4: Verificación final
# ============================================
echo "[4] Verificación final..."
echo "    [4.1] Comprobando si el usuario puede usar sudo..."

if grep -q "^${CURRENT_USER} ALL=(ALL:ALL) ALL$" /etc/sudoers 2>/dev/null; then
    echo "    ✓ Usuario tiene permisos de sudo configurados"
    echo ""
    echo "    Línea en sudoers:"
    grep "^${CURRENT_USER}" /etc/sudoers | sed 's/^/        /'
else
    echo "    ✗ Usuario NO tiene permisos de sudo"
    exit 1
fi
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║                                                          ║"
echo "║     ✓ Configuración de SUDO completada exitosamente      ║"
echo "║                                                          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
