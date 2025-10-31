#!/bin/bash
set -e

##############################
# Variables globales
##############################
DEBIAN_VERSION=""
REPOS="main"
MULTIMEDIA="no"
BACKPORTS="no"
INSTALL_TORBROWSER="no"
CONFIGURE_KITTY="no"
CONFIGURE_RIOTFETCH="no"
INSTALL_LIBREWOLF="no"
INSTALL_FIREFOX="no"

# Detectar si se ejecuta como root
RUN_AS_ROOT=false
if [ "$EUID" -eq 0 ]; then
    RUN_AS_ROOT=true
    USER_HOME="/home/$(logname 2>/dev/null || echo "${SUDO_USER:-}")"
    if [ -z "$USER_HOME" ] || [ "$USER_HOME" = "/home/" ]; then
        USER_HOME="/root"
    fi
    # Para root, usar log en /var/log
    LOG_FILE="/var/log/budgie_install.log"
else
    USER_HOME="$HOME"
    LOG_FILE="/tmp/budgie_install.log"
fi

# Configuración de idioma
LANGUAGE="en"
declare -A TRANSLATIONS

# Mapeo de idiomas para paquetes
declare -A LANGUAGE_PACKAGES
LANGUAGE_PACKAGES["en"]="en"
LANGUAGE_PACKAGES["es"]="es"  
LANGUAGE_PACKAGES["fr"]="fr"
LANGUAGE_PACKAGES["it"]="it"
LANGUAGE_PACKAGES["pt"]="pt"
LANGUAGE_PACKAGES["de"]="de"

##############################
# Sistema de traducción
##############################
load_translations() {
    case "$LANGUAGE" in
        "es") # Español
            TRANSLATIONS=(
                ["title"]="INSTALADOR DE BUDGIE DESKTOP"
                ["welcome"]="Bienvenido al instalador de Budgie Desktop para Debian"
                ["warning_root"]="ADVERTENCIA: Ejecutando como root. Las configuraciones de usuario se crearán para: $(logname 2>/dev/null || echo "${SUDO_USER:-desconocido}")"
                ["detecting_debian"]="Detectando versión de Debian..."
                ["debian_detected"]="Debian detectado"
                ["config_repos"]="Configurando repositorios..."
                ["repo_options"]="Opciones de repositorios disponibles:"
                ["repo_choice1"]="1) main (solo paquetes DFSG-compliant)"
                ["repo_choice2"]="2) main + contrib (DFSG-compliant que dependen de non-free)"
                ["repo_choice3"]="3) main + non-free (paquetes no-DFSG importantes)"
                ["repo_choice4"]="4) main + contrib + non-free + non-free-firmware (todos los componentes)"
                ["select_repo"]="Seleccione la opción de repositorios (1-4): "
                ["enable_multimedia"]="¿Desea habilitar repositorios multimedia? (y/n): "
                ["enable_backports"]="¿Desea habilitar backports? (y/n): "
                ["browser_selection"]="=== SELECCIÓN DE NAVEGADORES ==="
                ["install_librewolf"]="¿Desea instalar LibreWolf? (y/n): "
                ["install_firefox"]="¿Desea instalar Firefox? (y/n): "
                ["note_browsers"]="Nota: LibreWolf es más privado, Firefox es más compatible"
                ["optional_packages"]="=== CONFIGURACIÓN DE PAQUETES OPCIONALES ==="
                ["install_torbrowser"]="¿Desea instalar Tor Browser Launcher? (y/n): "
                ["configure_kitty"]="¿Desea configurar Kitty Terminal con temas personalizados? (y/n): "
                ["configure_riotfetch"]="¿Desea configurar RiotFetch (FastFetch personalizado)? (y/n): "
                ["installing_budgie"]="Instalando Budgie Desktop..."
                ["installation_complete"]="Instalación completada exitosamente"
                ["reboot_prompt"]="¿Desea reiniciar el sistema ahora? (y/n): "
                ["goodbye"]="Instalación completa. Reinicie el sistema más tarde para aplicar los cambios."
                ["cleaning_system"]="Limpiando sistema de paquetes innecesarios..."
                ["package_installed"]="instalado correctamente"
                ["package_already_installed"]="ya está instalado"
                ["package_unavailable"]="Paquete no disponible"
                ["package_failed"]="No se pudo instalar"
                ["configuring_firefox"]="Configurando Firefox..."
                ["configuring_librewolf"]="Configurando LibreWolf..."
                ["skipping_browser"]="Saltando instalación de navegador"
                ["installing_package"]="Instalando"
                ["browser_cleanup"]="Realizando limpieza de navegadores no deseados..."
                ["removing_unwanted_browser"]="Eliminando navegador no deseado"
                ["keeping_browser"]="Manteniendo navegador instalado por el usuario"
                ["libreoffice_language"]="Configurando LibreOffice en idioma"
            )
            ;;
        *) # English (default)
            TRANSLATIONS=(
                ["title"]="BUDGIE DESKTOP INSTALLER"
                ["welcome"]="Welcome to Budgie Desktop installer for Debian"
                ["warning_root"]="WARNING: Running as root. User configurations will be created for: $(logname 2>/dev/null || echo "${SUDO_USER:-unknown}")"
                ["detecting_debian"]="Detecting Debian version..."
                ["debian_detected"]="Debian detected"
                ["config_repos"]="Configuring repositories..."
                ["repo_options"]="Available repository options:"
                ["repo_choice1"]="1) main (DFSG-compliant packages only)"
                ["repo_choice2"]="2) main + contrib (DFSG-compliant with non-free dependencies)"
                ["repo_choice3"]="3) main + non-free (important non-DFSG packages)"
                ["repo_choice4"]="4) main + contrib + non-free + non-free-firmware (all components)"
                ["select_repo"]="Select repository option (1-4): "
                ["enable_multimedia"]="Enable multimedia repositories? (y/n): "
                ["enable_backports"]="Enable backports? (y/n): "
                ["browser_selection"]="=== BROWSER SELECTION ==="
                ["install_librewolf"]="Install LibreWolf? (y/n): "
                ["install_firefox"]="Install Firefox? (y/n): "
                ["note_browsers"]="Note: LibreWolf is more private, Firefox is more compatible"
                ["optional_packages"]="=== OPTIONAL PACKAGES CONFIGURATION ==="
                ["install_torbrowser"]="Install Tor Browser Launcher? (y/n): "
                ["configure_kitty"]="Configure Kitty Terminal with custom themes? (y/n): "
                ["configure_riotfetch"]="Configure RiotFetch (custom FastFetch)? (y/n): "
                ["installing_budgie"]="Installing Budgie Desktop..."
                ["installation_complete"]="Installation completed successfully"
                ["reboot_prompt"]="Reboot system now? (y/n): "
                ["goodbye"]="Installation complete. Reboot system later to apply changes."
                ["cleaning_system"]="Cleaning system of unnecessary packages..."
                ["package_installed"]="installed successfully"
                ["package_already_installed"]="already installed"
                ["package_unavailable"]="Package unavailable"
                ["package_failed"]="Failed to install"
                ["configuring_firefox"]="Configuring Firefox..."
                ["configuring_librewolf"]="Configuring LibreWolf..."
                ["skipping_browser"]="Skipping browser installation"
                ["installing_package"]="Installing"
                ["browser_cleanup"]="Performing unwanted browsers cleanup..."
                ["removing_unwanted_browser"]="Removing unwanted browser"
                ["keeping_browser"]="Keeping user-installed browser"
                ["libreoffice_language"]="Configuring LibreOffice in language"
            )
            ;;
    esac
}

translate() {
    local key="$1"
    echo "${TRANSLATIONS[$key]:-$key}"
}

select_language() {
    echo "=== LANGUAGE SELECTION ==="
    echo "1) English"
    echo "2) Español"
    echo "3) Français"
    echo "4) Italiano"
    echo "5) Português"
    echo "6) Deutsch"
    read -p "Select language (1-6): " lang_choice

    case $lang_choice in
        1) LANGUAGE="en" ;;
        2) LANGUAGE="es" ;;
        3) LANGUAGE="fr" ;;
        4) LANGUAGE="it" ;;
        5) LANGUAGE="pt" ;;
        6) LANGUAGE="de" ;;
        *) LANGUAGE="en" ;;
    esac

    load_translations
    echo ""
}

##############################
# Funciones de utilidad MEJORADAS para soporte root
##############################
log_message() {
    local message="$1"
    local timestamp=$(date)
    
    # Mostrar mensaje en pantalla
    echo "$timestamp: $message"
    
    # Intentar escribir en log file, pero no fallar si no puede
    {
        echo "$timestamp: $message" >> "$LOG_FILE"
    } 2>/dev/null || true
}

# Función para ejecutar comandos como usuario correcto
run_as_user() {
    if [ "$RUN_AS_ROOT" = true ] && [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" "$@"
    else
        "$@"
    fi
}

# Función para crear directorios con permisos correctos
create_user_dir() {
    local dir="$1"
    if [ "$RUN_AS_ROOT" = true ] && [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" mkdir -p "$dir"
        sudo -u "$SUDO_USER" chmod 755 "$dir"
    else
        mkdir -p "$dir"
        chmod 755 "$dir"
    fi
}

check_dependencies() {
    local deps=("curl" "wget")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_message "Installing dependency: $dep"
            apt install -y "$dep"
        fi
    done
}

run_sudo() {
    # Si ya somos root, no usar sudo
    if [ "$RUN_AS_ROOT" = true ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Función mejorada para instalar paquetes
install_packages() {
    local packages=("$@")
    
    for package in "${packages[@]}"; do
        if apt-cache show "$package" &> /dev/null; then
            if ! dpkg -l | grep -q "^ii  $package "; then
                log_message "$(translate "installing_package") $package..."
                if run_sudo apt install -y "$package"; then
                    log_message "✓ $package $(translate "package_installed")"
                else
                    log_message "⚠ $(translate "package_failed") $package"
                fi
            else
                log_message "✓ $package $(translate "package_already_installed")"
            fi
        else
            log_message "⚠ $(translate "package_unavailable"): $package"
        fi
    done
}

##############################
# Funciones principales
##############################

# Detectar versión de Debian
detect_debian_version() {
    log_message "$(translate "detecting_debian")"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_message "$(translate "debian_detected"): $VERSION_CODENAME ($VERSION_ID)"
        DEBIAN_VERSION="$VERSION_CODENAME"
    else
        log_message "ERROR: $(translate "debian_detected")"
        exit 1
    fi
}

# Preguntar por repositorios, backports y multimedia
configure_repositories() {
    echo "$(translate "config_repos")"
    echo "$(translate "repo_options")"
    echo "$(translate "repo_choice1")"
    echo "$(translate "repo_choice2")"
    echo "$(translate "repo_choice3")"
    echo "$(translate "repo_choice4")"
    read -p "$(translate "select_repo")" repo_choice

    case $repo_choice in
        1) REPOS="main" ;;
        2) REPOS="main contrib" ;;
        3) REPOS="main non-free" ;;
        4) REPOS="main contrib non-free non-free-firmware" ;;
        *) echo "Invalid option, using main" ; REPOS="main" ;;
    esac

    read -p "$(translate "enable_multimedia")" enable_multimedia
    [[ "$enable_multimedia" =~ ^[Yy]$ ]] && MULTIMEDIA="yes" || MULTIMEDIA="no"

    read -p "$(translate "enable_backports")" enable_backports
    [[ "$enable_backports" =~ ^[Yy]$ ]] && BACKPORTS="yes" || BACKPORTS="no"
}

# Preguntar por navegadores
configure_browsers() {
    echo ""
    echo "$(translate "browser_selection")"
    echo ""
    echo "$(translate "note_browsers")"
    echo ""
    
    read -p "$(translate "install_librewolf")" enable_librewolf
    [[ "$enable_librewolf" =~ ^[Yy]$ ]] && INSTALL_LIBREWOLF="yes" || INSTALL_LIBREWOLF="no"
    
    read -p "$(translate "install_firefox")" enable_firefox
    [[ "$enable_firefox" =~ ^[Yy]$ ]] && INSTALL_FIREFOX="yes" || INSTALL_FIREFOX="no"
}

# Preguntar por paquetes opcionales
configure_optional_packages() {
    echo ""
    echo "$(translate "optional_packages")"
    echo ""
    
    read -p "$(translate "install_torbrowser")" enable_torbrowser
    [[ "$enable_torbrowser" =~ ^[Yy]$ ]] && INSTALL_TORBROWSER="yes" || INSTALL_TORBROWSER="no"
    
    read -p "$(translate "configure_kitty")" enable_kitty
    [[ "$enable_kitty" =~ ^[Yy]$ ]] && CONFIGURE_KITTY="yes" || CONFIGURE_KITTY="no"
    
    read -p "$(translate "configure_riotfetch")" enable_riotfetch
    [[ "$enable_riotfetch" =~ ^[Yy]$ ]] && CONFIGURE_RIOTFETCH="yes" || CONFIGURE_RIOTFETCH="no"
}

# Configurar repositorio multimedia
configure_multimedia_repo() {
    if [[ "$MULTIMEDIA" == "yes" ]]; then
        log_message "Configuring multimedia repository..."
        cd /tmp
        wget -q https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb
        run_sudo dpkg -i deb-multimedia-keyring_2024.9.1_all.deb
        rm -f deb-multimedia-keyring_2024.9.1_all.deb
        cd - > /dev/null
    fi
}

# Configurar Firefox
configure_firefox() {
    if [[ "$INSTALL_FIREFOX" == "yes" ]]; then
        log_message "$(translate "configuring_firefox")"
        
        wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | run_sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
        
        if [[ "$DEBIAN_VERSION" == "bookworm" ]]; then
            echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | run_sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null
        else
            run_sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null << EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
        fi
        
        run_sudo apt update
        log_message "$(translate "installing_package") Firefox..."
        install_packages firefox
    else
        log_message "$(translate "skipping_browser") Firefox"
    fi
}

# Configurar LibreWolf
configure_librewolf() {
    if [[ "$INSTALL_LIBREWOLF" == "yes" ]]; then
        log_message "$(translate "configuring_librewolf")"
        
        run_sudo extrepo enable librewolf
        run_sudo apt update
        install_packages librewolf
    else
        log_message "$(translate "skipping_browser") LibreWolf"
    fi
}

# Instalar Tor Browser Launcher
install_torbrowser() {
    if [[ "$INSTALL_TORBROWSER" == "yes" ]]; then
        log_message "$(translate "installing_package") Tor Browser Launcher..."
        install_packages torbrowser-launcher
    else
        log_message "Skipping Tor Browser Launcher installation"
    fi
}

# Actualizar sources.list para Bookworm
update_sources_list_bookworm() {
    run_sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
    run_sudo bash -c "cat > /etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian bookworm $REPOS
deb-src http://deb.debian.org/debian bookworm $REPOS
deb http://security.debian.org/debian-security bookworm-security $REPOS
deb-src http://security.debian.org/debian-security bookworm-security $REPOS
EOF

    [[ "$BACKPORTS" == "yes" ]] && run_sudo bash -c "echo 'deb http://deb.debian.org/debian bookworm-backports $REPOS' >> /etc/apt/sources.list"
    
    if [[ "$MULTIMEDIA" == "yes" ]]; then
        configure_multimedia_repo
    fi
    
    run_sudo apt update
}

# Actualizar sources.list para Trixie (nuevo formato)
update_sources_list_trixie() {
    run_sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

    run_sudo bash -c "cat > /etc/apt/sources.list.d/debian.sources" << EOF
Types: deb deb-src
URIs: https://deb.debian.org/debian
Suites: trixie trixie-updates
Components: $REPOS
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: https://security.debian.org/debian-security
Suites: trixie-security
Components: $REPOS
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

    if [[ "$BACKPORTS" == "yes" ]]; then
        run_sudo bash -c "cat > /etc/apt/sources.list.d/debian-backports.sources" << EOF
Types: deb deb-src
URIs: https://deb.debian.org/debian
Suites: trixie-backports
Components: $REPOS
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    fi

    if [[ "$MULTIMEDIA" == "yes" ]]; then
        configure_multimedia_repo
        run_sudo bash -c "cat > /etc/apt/sources.list.d/dmo.sources" << EOF
Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie
Components: main non-free
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
Enabled: yes

Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
Enabled: yes
EOF
    fi

    run_sudo apt update
}

# Obtener paquetes de LibreOffice según el idioma
get_libreoffice_packages() {
    local lang_code="${LANGUAGE_PACKAGES[$LANGUAGE]}"
    
    local base_packages=(
        "libreoffice-calc"
        "libreoffice-writer" 
        "libreoffice-style-elementary"
        "libreoffice-gnome"
    )
    
    case "$lang_code" in
        "es")
            base_packages+=("libreoffice-help-es" "libreoffice-l10n-es")
            ;;
        "fr")
            base_packages+=("libreoffice-help-fr" "libreoffice-l10n-fr")
            ;;
        "it")
            base_packages+=("libreoffice-help-it" "libreoffice-l10n-it")
            ;;
        "pt")
            base_packages+=("libreoffice-help-pt" "libreoffice-l10n-pt")
            ;;
        "de")
            base_packages+=("libreoffice-help-de" "libreoffice-l10n-de")
            ;;
        *) # English
            base_packages+=("libreoffice-help-en-us" "libreoffice-l10n-en")
            ;;
    esac
    
    echo "${base_packages[@]}"
}

# Instalar Budgie en Bookworm
install_budgie_bookworm() {
    log_message "$(translate "installing_budgie")"
    
    local base_packages=(
        kitty thunar thunar-volman thunar-archive-plugin
        budgie-desktop budgie* slick-greeter extrepo font-manager synaptic
        xorg apt-xapian-index build-essential linux-headers-amd64
        make automake nala cmake autoconf git wget
        appstream-util acpi acpitool acpi-support rename fancontrol
        firmware-linux-free hardinfo hwdata hwinfo irqbalance
        iucode-tool laptop-detect lm-sensors lshw lsscsi smartmontools
        software-properties-gtk gnome-disk-utility gparted
        menu-l10n ooo-thumbnailer fonts-jetbrains-mono fonts-recommended
        fonts-ubuntu fonts-font-awesome fonts-terminus fonts-inter
        arj bzip2 gzip lhasa lzip lzma p7zip p7zip-full p7zip-rar
        sharutils rar unace unrar unrar-free tar unzip xz-utils zip
        ffmpeg
        gstreamer1.0-libav gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad
        gstreamer1.0-pulseaudio vorbis-tools flac default-jdk default-jre
        dconf-editor clang curl valac meson lollypop mpv shotwell xarchiver
        fonts-firacode pluma amberol thunderbird atril galculator diodon 
        mate-system-monitor fastfetch
        fonts-noto-color-emoji fonts-symbola
    )

    install_packages "${base_packages[@]}"
    
    local firmware_packages=("firmware-linux" "firmware-misc-nonfree" "amd64-microcode" "intel-microcode")
    for pkg in "${firmware_packages[@]}"; do
        if apt-cache show "$pkg" &> /dev/null; then
            install_packages "$pkg"
        fi
    done
    
    configure_librewolf
    configure_firefox

    log_message "$(translate "libreoffice_language") $LANGUAGE..."
    local libreoffice_packages=($(get_libreoffice_packages))
    install_packages "${libreoffice_packages[@]}"
}

# Instalar Budgie en Trixie
install_budgie_trixie() {
    log_message "$(translate "installing_budgie")"
    
    local packages_to_remove=("nemo" "file-roller" "gedit")
    for pkg in "${packages_to_remove[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            run_sudo apt purge -y "$pkg"
        fi
    done
    
    local base_packages=(
        kitty thunar thunar-volman thunar-archive-plugin
        budgie-desktop budgie* slick-greeter extrepo synaptic
        xorg build-essential linux-headers-amd64
        make automake nala cmake autoconf git wget
        appstream-util acpi acpitool acpi-support rename fancontrol
        firmware-linux-free hardinfo hwdata hwinfo irqbalance
        iucode-tool laptop-detect lm-sensors lshw lsscsi smartmontools
        gnome-disk-utility gparted
        menu-l10n ooo-thumbnailer fonts-jetbrains-mono fonts-recommended
        fonts-ubuntu fonts-font-awesome fonts-terminus fonts-inter
        arj bzip2 gzip lhasa lzip lzma p7zip p7zip-full p7zip-rar
        sharutils rar unace unrar unrar-free tar unzip xz-utils zip
        ffmpeg
        gstreamer1.0-libav gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad
        gstreamer1.0-pulseaudio vorbis-tools flac default-jdk default-jre
        dconf-editor clang curl valac meson mpv shotwell xarchiver
        fonts-firacode pluma amberol thunderbird atril galculator diodon 
        fastfetch fonts-noto-color-emoji fonts-symbola 
    )

    install_packages "${base_packages[@]}"
    
    local firmware_packages=("firmware-linux" "firmware-misc-nonfree" "amd64-microcode" "intel-microcode")
    for pkg in "${firmware_packages[@]}"; do
        if apt-cache show "$pkg" &> /dev/null; then
            install_packages "$pkg"
        fi
    done
    
    configure_librewolf
    configure_firefox

    log_message "$(translate "libreoffice_language") $LANGUAGE..."
    local libreoffice_packages=($(get_libreoffice_packages))
    install_packages "${libreoffice_packages[@]}"
}

# Configuración de mpv
configure_mpv() {
    local config_dir="$USER_HOME/.config/mpv"
    local config_file="$config_dir/mpv.conf"
    
    create_user_dir "$config_dir"
    
    if [ -f "$config_file" ]; then
        run_as_user mv "$config_file" "$config_file.bak"
        log_message "Backup de mpv.conf creado"
    fi
    
    local mpv_config='# Configuración básica de MPV
profile=gpu-hq
hwdec=auto-safe
vo=gpu
gpu-context=wayland,x11

scale=ewa_lanczossharp
dscale=mitchell
cscale=ewa_lanczossharp

sub-auto=fuzzy
sub-font-size=55
sub-border-size=2.5
sub-border-color=#262626
sub-shadow-color=#000000
sub-shadow-offset=1.5

save-position-on-quit=yes
watch-later-options=start,vid,aid,sid'
    
    echo "$mpv_config" | run_as_user tee "$config_file" > /dev/null
    run_as_user chmod 644 "$config_file"
    log_message "Configuración de MPV creada en: $config_file"
}

# Configuración LightDM y GRUB MEJORADA
configure_lightdm_grub() {
    local lightdm_file="/etc/lightdm/lightdm.conf"
    if [ -f "$lightdm_file" ]; then
        run_sudo sed -i 's/^#user-session=default/user-session=budgie-desktop/' "$lightdm_file"
        log_message "LightDM actualizado a Budgie"
    else
        log_message "LightDM no encontrado, omitiendo configuración"
    fi

    # Configuración diferente para Bookworm vs Trixie
    local grub_cmdline=""
    case "$DEBIAN_VERSION" in
        "bookworm")
            grub_cmdline="quiet nowatchdog loglevel=3"
            log_message "Configurando GRUB para Bookworm: $grub_cmdline"
            ;;
        "trixie")
            grub_cmdline="quiet loglevel=1 rd.udev.log_level=0 systemd.show_status=false"
            log_message "Configurando GRUB para Trixie: $grub_cmdline"
            ;;
        *)
            grub_cmdline="quiet nowatchdog loglevel=3"
            log_message "Configurando GRUB por defecto: $grub_cmdline"
            ;;
    esac

    run_sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$grub_cmdline\"/" /etc/default/grub
    run_sudo update-grub
    log_message "GRUB configurado para $DEBIAN_VERSION"
}

# Reinstalar Bluetooth solo en Bookworm
reinstall_bluetooth() {
    if [[ "$DEBIAN_VERSION" == "bookworm" ]]; then
        log_message "Reinstalando Bluetooth para Bookworm..."
        run_sudo apt purge -y pulseaudio-module-bluetooth bluetooth "bluez-*" bluez
        run_sudo rm -fr /var/lib/blueman /var/lib/bluetooth/
        run_sudo apt install -y bluez pulseaudio-module-bluetooth --install-suggests
        log_message "Bluetooth reinstalado"
    else
        log_message "Saltando reinstalación de Bluetooth en Trixie"
    fi
}

# Configurar NetworkManager
configure_networkmanager() {
    run_sudo bash -c 'cat > /etc/NetworkManager/NetworkManager.conf' << EOF
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF
    run_sudo service NetworkManager restart
    log_message "NetworkManager configurado"
}

# Configuración de Kitty Terminal
configure_kitty_terminal() {
    if [[ "$CONFIGURE_KITTY" == "yes" ]]; then
        log_message "Configurando Kitty Terminal con temas personalizados..."
        
        local config_dir="$USER_HOME/.config/kitty"
        create_user_dir "$config_dir"
        
        local kitty_config='# Kitty Terminal Configuration
enable_audio_bell no
background_opacity 0.90

font_family FiraCode Nerd Font Mono
font_size 10.0

# Nord Color Scheme
foreground #D8DEE9
background #2E3440

color0 #3B4252
color1 #BF616A
color2 #A3BE8C
color3 #EBCB8B
color4 #81A1C1
color5 #B48EAD
color6 #88C0D0
color7 #E5E9F0
color8 #4C566A
color9 #BF616A
color10 #A3BE8C
color11 #EBCB8B
color12 #81A1C1
color13 #B48EAD
color14 #88C0D0
color15 #ECEFF4'
        
        echo "$kitty_config" | run_as_user tee "$config_dir/kitty.conf" > /dev/null
        run_as_user chmod 644 "$config_dir/kitty.conf"
        log_message "✅ Kitty Terminal configurado correctamente"
    else
        log_message "Saltando configuración de Kitty"
    fi
}

# Configuración MEJORADA de RiotFetch según tu script
configure_riotfetch() {
    if [[ "$CONFIGURE_RIOTFETCH" == "yes" ]]; then
        log_message "Configurando RiotFetch (FastFetch personalizado)..."
        
        # Instalar FastFetch si no está disponible
        if ! command -v fastfetch &> /dev/null; then
            log_message "Instalando FastFetch..."
            install_packages fastfetch
        fi
        
        local CONFIG_DIR="$USER_HOME/.config/fastfetch"
        local REPO_URL="https://github.com/qazlinux/riotfetch"
        local TEMP_DIR="$CONFIG_DIR/riotfetch"
        
        echo "──────────────────────────────────────────────"
        echo " Fastfetch Theme Installer — RiotFetch"
        echo "──────────────────────────────────────────────"
        
        # 1️⃣ Crear el directorio de configuración si no existe
        if [ ! -d "$CONFIG_DIR" ]; then
            echo "[1/4] Creando directorio de configuración..."
            create_user_dir "$CONFIG_DIR"
        else
            echo "[1/4] El directorio de configuración ya existe. Continuando..."
        fi
        
        # 2️⃣ Entrar al directorio y clonar el repositorio
        run_as_user cd "$CONFIG_DIR"
        
        if [ -d "$TEMP_DIR" ]; then
            echo "[2/4] Eliminando versión anterior de RiotFetch..."
            run_as_user rm -rf "$TEMP_DIR"
        fi
        
        echo "[2/4] Clonando el tema RiotFetch..."
        run_as_user git clone --depth=1 "$REPO_URL" "$TEMP_DIR"
        
        # 3️⃣ Mover los archivos desde riotfetch/ a ~/.config/fastfetch/
        echo "[3/4] Moviendo archivos del tema al directorio principal..."
        run_as_user shopt -s dotglob nullglob
        run_as_user mv "$TEMP_DIR"/* "$CONFIG_DIR"/
        run_as_user shopt -u dotglob nullglob
        
        # 4️⃣ Eliminar el directorio vacío riotfetch
        echo "[4/4] Eliminando carpeta temporal riotfetch..."
        run_as_user rm -rf "$TEMP_DIR"
        
        echo "──────────────────────────────────────────────"
        echo " Instalación completada con éxito ✅"
        echo " Archivos del tema ubicados en: $CONFIG_DIR"
        echo "──────────────────────────────────────────────"
        echo " Puedes ejecutar ahora:"
        echo "   fastfetch --config $CONFIG_DIR/config.jsonc"
        echo "──────────────────────────────────────────────"
        
        log_message "✅ RiotFetch configurado exitosamente"
        
    else
        log_message "Saltando configuración de RiotFetch"
    fi
}

# Limpieza inteligente de navegadores
clean_browsers() {
    log_message "$(translate "browser_cleanup")"
    
    local potential_browsers=("firefox-esr" "chromium" "firefox")
    
    for browser in "${potential_browsers[@]}"; do
        if dpkg -l | grep -q "^ii  $browser "; then
            case "$browser" in
                "firefox")
                    if [[ "$INSTALL_FIREFOX" != "yes" ]]; then
                        log_message "$(translate "removing_unwanted_browser"): $browser"
                        run_sudo apt purge -y "$browser" "$browser"-l10n-*
                    else
                        log_message "$(translate "keeping_browser"): $browser"
                    fi
                    ;;
                "firefox-esr")
                    log_message "$(translate "removing_unwanted_browser"): $browser"
                    run_sudo apt purge -y "$browser" "$browser"-l10n-*
                    ;;
                "chromium")
                    log_message "$(translate "removing_unwanted_browser"): $browser"
                    run_sudo apt purge -y "$browser" "$browser"-l10n
                    ;;
            esac
        fi
    done
}

# Limpiar sistema
clean_system() {
    log_message "$(translate "cleaning_system")"
    
    clean_browsers
    
    log_message "Realizando limpieza general del sistema..."
    run_sudo apt autoremove --purge -y
    run_sudo apt autoclean
    run_sudo apt clean
    
    log_message "Limpieza del sistema completada"
}

##############################
# Ejecución principal
##############################
main() {
    # Inicializar archivo de log
    if [ "$RUN_AS_ROOT" = true ]; then
        touch "$LOG_FILE" 2>/dev/null && chmod 644 "$LOG_FILE" || true
    else
        touch "$LOG_FILE" 2>/dev/null || true
    fi
    
    # Selección de idioma primero
    select_language
    
    echo ""
    echo "=== $(translate "title") ==="
    echo "$(translate "welcome")"
    echo ""
    
    if [ "$RUN_AS_ROOT" = true ]; then
        echo "$(translate "warning_root")"
        echo ""
    fi
    
    log_message "Iniciando instalación de Budgie Desktop"
    
    check_dependencies
    detect_debian_version
    configure_repositories
    configure_browsers

    case "$DEBIAN_VERSION" in
        "bookworm")
            update_sources_list_bookworm
            install_budgie_bookworm
            ;;
        "trixie")
            update_sources_list_trixie
            install_budgie_trixie
            ;;
        *)
            log_message "Versión no soportada automáticamente: $DEBIAN_VERSION. Usando Bookworm por defecto."
            update_sources_list_bookworm
            install_budgie_bookworm
            ;;
    esac

    configure_mpv
    configure_lightdm_grub
    reinstall_bluetooth
    configure_networkmanager
    
    # Preguntar por paquetes opcionales DESPUÉS de la instalación base
    configure_optional_packages
    
    # Instalar Tor Browser Launcher si se solicitó
    install_torbrowser
    
    # Configurar Kitty Terminal si se solicitó
    configure_kitty_terminal
    
    # Configurar RiotFetch si se solicitó (MÉTODO MEJORADO)
    configure_riotfetch
    
    # Limpiar sistema antes de finalizar
    clean_system

    log_message "$(translate "installation_complete")"
    
    read -p "$(translate "reboot_prompt")" response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_message "Reiniciando sistema..."
        run_sudo reboot
    else
        echo "$(translate "goodbye")"
    fi
}

# Ejecutar función principal
main "$@"
