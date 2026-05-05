#!/usr/bin/env python3
"""
i3 window title icon injector.
Agrega iconos antes del nombre de la ventana basándose en su clase WM_CLASS.
"""

import os
import subprocess
import time
import logging

# Configuración de iconos por clase de ventana
# Podés agregar más/iconos diferentes
ICON_MAP = {
    # Navegadores
    "firefox": "🌐",
    "Firefox": "🌐",
    "Chromium": "🌐",
    "chrome": "🌐",
    "Brave-browser": "🦁",
    
    # Terminales
    "lxterminal": "⬛",
    "xfce4-terminal": "⬛",
    "gnome-terminal": "⬛",
    "kitty": "🐱",
    "alacritty": "⬛",
    "wezterm": "⬛",
    "terminator": "⬛",
    
    # Editores / IDE
    "code": "📝",
    "Code": "📝",
    "VSCodium": "📝",
    "subl": "📝",
    "Sublime_text": "📝",
    "gedit": "📝",
    "nvim": "📝",
    "vim": "📝",
    
    # Correo / Chat
    "thunderbird": "📧",
    "Thunderbird": "📧",
    "discord": "💬",
    "Slack": "💬",
    "telegram": "✈️",
    "Signal": "🔐",
    
    # Sistema
    "pcmanfm": "📁",
    "Thunar": "📁",
    "nautilus": "📁",
    "dolphin": "📁",
    "ranger": "📁",
    
    # Multimedia
    "vlc": "🎬",
    "VLC": "🎬",
    "mpv": "🎬",
    "spotify": "🎵",
    
    # Utilidades
    "htop": "📊",
    "btop": "📊",
    "nvtop": "📊",
    "nvtop.bin": "📊",
    "qps": "📊",
    "flameshot": "📸",
    "scrot": "📸",
    
    # Misc
    "libreoffice": "📄",
    "soffice": "📄",
    "evince": "📄",
    "zathura": "📚",
    "evince": "📚",
    "obs": "🎥",
    "Yad": "⚙️",
    "yad": "⚙️",
    "mailspring": "📧",
}

# Icono por defecto si no se encuentra la clase
DEFAULT_ICON = "🪟"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/tmp/i3-title-icons.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def get_tree():
    """Obtiene el tree de i3."""
    try:
        result = subprocess.run(
            ["i3-msg", "-t", "get_tree"],
            capture_output=True,
            text=True,
            timeout=5
        )
        import json
        return json.loads(result.stdout)
    except Exception as e:
        logger.error(f"Error getting tree: {e}")
        return None


def find_windows(node, windows=None):
    """Encuentra todas las ventanas en el tree."""
    if windows is None:
        windows = []
    
    if "window" in node:
        windows.append(node)
    
    if "nodes" in node:
        for child in node["nodes"]:
            find_windows(child, windows)
    
    if "floating_nodes" in node:
        for child in node["floating_nodes"]:
            find_windows(child, windows)
    
    return windows


def set_window_title(window_id, icon, title):
    """Setea el título de la ventana con el icono."""
    new_title = f"{icon} {title}"
    try:
        subprocess.run(
            ["i3-msg", f"[id={window_id}] title_format '{new_title}'"],
            check=True,
            timeout=2
        )
        logger.info(f"Set title for {window_id}: {new_title}")
    except Exception as e:
        logger.error(f"Error setting title for {window_id}: {e}")


def get_icon_for_class(window_class):
    """Obtiene el icono para una clase de ventana."""
    # Buscar coincidencia exacta o parcial
    for cls, icon in ICON_MAP.items():
        if cls.lower() in window_class.lower():
            return icon
    
    # Si no hay coincidencia, buscar al final
    for cls, icon in ICON_MAP.items():
        if window_class.lower().endswith(cls.lower()):
            return icon
    
    return None


def main():
    """Loop principal."""
    logger.info("Starting i3 title icon injector...")
    processed = set()
    
    while True:
        try:
            tree = get_tree()
            if tree:
                windows = find_windows(tree)
                
                for win in windows:
                    window_id = win.get("window")
                    if not window_id:
                        continue
                    
                    # Ya procesado?
                    if window_id in processed:
                        continue
                    
                    # Obtener clase y título
                    window_props = win.get("window_properties", {})
                    window_class = window_props.get("class", "")
                    title = win.get("name", "")
                    
                    if not window_class:
                        continue
                    
                    # Buscar icono
                    icon = get_icon_for_class(window_class)
                    if not icon:
                        icon = DEFAULT_ICON
                    
                    # Aplicar título
                    set_window_title(window_id, icon, title)
                    processed.add(window_id)
            
            time.sleep(1)
            
        except KeyboardInterrupt:
            logger.info("Exiting...")
            break
        except Exception as e:
            logger.error(f"Error: {e}")
            time.sleep(5)


if __name__ == "__main__":
    main()