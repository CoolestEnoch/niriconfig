#!/bin/bash

log() {
    local GREEN='\033[0;32m'
    local NC='\033[0m'
    if [ "$1" ]; then
        echo -e "${GREEN}[$(date)] - $*${NC}" >&2
    fi
}

# Example:
# get_config_value "YOUR_KEY" "Tip for user to enter"
get_config_value() {
    local key="$1"
    local tip="$2"
    local config_file="./config.txt"
    local value=""
    local need_save=false
    local output=""
    
    if [[ ! -f "$config_file" ]]; then
        touch "$config_file"
        echo "Created config file: $config_file" >&2
    fi
    
    if [[ -f "$config_file" ]]; then
        if [[ -s "$config_file" ]]; then
            source "$config_file" 2>/dev/null || true
        fi
        
        eval "value=\"\$$key\""
        
        if [[ -n "$value" ]]; then
            echo "Got $key: $value" >&2
        else
            echo "$key is not set in config file!" >&2
            read -p "$tip" value
            need_save=true
        fi
    fi
    
    if [[ "$need_save" == true ]]; then
        local config_content=""
        if [[ -f "$config_file" && -s "$config_file" ]]; then
            config_content=$(cat "$config_file")
        fi
        
        if echo "$config_content" | grep -q "^$key="; then
            config_content=$(echo "$config_content" | sed "s/^$key=.*/$key=$value/")
            echo "$config_content" > "$config_file"
        else
            echo "$key=$value" >> "$config_file"
        fi
        
        echo "Saved $key=$value to $config_file" >&2
    fi
    
    echo "$value"
}

deploy_dotconfig_dirs() {
    local name="$1"
    local -n dirs="$2"
    local src_base="dotconfig"
    local dst_base="$HOME/.config"

    log "[$name] Removing files..."
    for d in "${dirs[@]}"; do
        rm -rv "${dst_base}/${d}"
    done

    log "[$name] Copying files..."
    for d in "${dirs[@]}"; do
        cp -ruv "${src_base}/${d}" "${dst_base}/"
    done
}

get_noctalia_version() {
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local config_dirs="${XDG_CONFIG_DIRS:-/etc/xdg}"
    local config_dir

    # v5 优先；v4 和 v5 同时存在时返回 v5
    if command -v noctalia >/dev/null 2>&1; then
        printf '%s\n' "v5"
        return 0
    fi

    # 部分发行版可能提供独立的 noctalia-shell 命令
    if command -v noctalia-shell >/dev/null 2>&1; then
        printf '%s\n' "v4"
        return 0
    fi

    # v4 通常使用 qs，并以 noctalia-shell 作为 Quickshell 配置
    if command -v qs >/dev/null 2>&1; then
        # 用户级手动安装
        if [[ -d "$config_home/quickshell/noctalia-shell" ]]; then
            printf '%s\n' "v4"
            return 0
        fi

        # 系统级安装，例如 /etc/xdg/quickshell/noctalia-shell
        while IFS= read -r config_dir; do
            if [[ -d "$config_dir/quickshell/noctalia-shell" ]]; then
                printf '%s\n' "v4"
                return 0
            fi
        done < <(printf '%s' "$config_dirs" | tr ':' '\n')
    fi

    printf '%s\n' "null"
}

deploy_noctalia() {
    rm -r $HOME/.cache/noctalia*
    noctalia_version="$(get_noctalia_version)"

    case "$noctalia_version" in
        v5)
            log "执行 v5 部署逻辑"
            deploy_noctaliav5
            ;;
        v4)
            log "执行 v4 部署逻辑"
            deploy_noctaliav4
            ;;
        null)
            log "未检测到 Noctalia"
            ;;
    esac
}

deploy_noctaliav4() {
    log "[noctalia] Reading config..."
    local config_file="config.txt"
    local script_dir=$(dirname "$(readlink -f "$0")")
    local LOCATION_WEATHER=$(get_config_value "LOCATION_WEATHER" "Enter your LOCATION for weather: ")
    
    
    log "[noctalia] Copying files..."
    local include_dirs=("niri" "noctalia")
    for dir in "${include_dirs[@]}"; do
        cp -ruv dotconfig/$dir $HOME/.config/
    done
    local include_systemd_services=("noctalia")
    mkdir -p ${HOME}/.config/systemd/user
    for serv in "${include_systemd_services[@]}"; do
        cp -ruv "dotconfig/systemd/user/${serv}.service" "${HOME}/.config/systemd/user/${serv}.service"
    done
    
    log "[noctalia] Reloading services..."
    systemctl --user daemon-reload
    systemctl --user add-wants niri.service noctalia.service
    systemctl --user mask swaync.service
    
    sed -i "s/\"name\": \"LOCATION\"/\"name\": \"$LOCATION_WEATHER\"/g" "$HOME/.config/noctalia/settings.json"
    sed -i "s/USERNAME/$(whoami)/g" "$HOME/.config/noctalia/settings.json"
    sed -i "s/^spawn-at-startup \"waybar\".*/\/\/spawn-at-startup \"waybar\"/" $HOME/.config/niri/config.kdl
    sed -i 's#swaylock & niri msg action power-off-monitors#qs -c noctalia-shell ipc call lockScreen lock#g' $HOME/.config/niri/config.kdl
    sed -i 's/vicinae toggle/qs -c noctalia-shell ipc call launcher clipboard/g' $HOME/.config/niri/config.kdl
    sed -i 's/wallpaper\$/noctalia-overview\*/g' $HOME/.config/niri/config.kdl
    niri msg action spawn-sh -- "qs -c noctalia-shell > /dev/null 2>&1"
    systemctl --user restart --now noctalia.service 
}

deploy_noctaliav5() {
    log "[noctalia] Reading config..."
    local config_file="config.txt"
    local script_dir=$(dirname "$(readlink -f "$0")")
    local LOCATION_WEATHER=$(get_config_value "LOCATION_WEATHER" "Enter your LOCATION for weather: ")
    
    
    log "[noctalia] Copying files..."
    local include_dirs=("niri")
    for dir in "${include_dirs[@]}"; do
        cp -ruv dotconfig/$dir $HOME/.config/
    done
    local include_dirs=("noctalia")
    for dir in "${include_dirs[@]}"; do
        rm -rfv $HOME/.local/state/$dir
        cp -ruv dotlocalstate/$dir $HOME/.local/state/
    done
    
    log "[noctalia] Reloading services..."
    systemctl --user daemon-reload
    systemctl --user mask swaync.servicei

    mkdir -p /tmp/noctalia/clipboard/entries
    ln -s /tmp/noctalia/clipboard $HOME/.local/state/noctalia/clipboard
    
    sed -i "s#address = \"LOCATION\"#address = \"$LOCATION_WEATHER\"#g" "$HOME/.local/state/noctalia/settings.toml"
    sed -i "s/USERNAME/$(whoami)/g" "$HOME/.local/state/noctalia/settings.toml"
    sed -i "s#^spawn-at-startup \"waybar\".*#spawn-at-startup \"noctalia\"#" $HOME/.config/niri/config.kdl
    sed -i 's#swaylock & niri msg action power-off-monitors#noctalia msg session lock#g' $HOME/.config/niri/config.kdl
    sed -i 's/vicinae toggle/noctalia msg panel-toggle clipboard/g' $HOME/.config/niri/config.kdl
    sed -i 's/wallpaper\$/noctalia-backdrop\*/g' $HOME/.config/niri/config.kdl
    niri msg action spawn-sh -- "noctalia > /dev/null 2>&1"
}

deploy_waybar() {
    log "[waybar] Copying files..."
    local include_dirs=("niri" "swaylock" "swaync" "waybar")
    for dir in "${include_dirs[@]}"; do
        cp -ruv dotconfig/$dir $HOME/.config/
    done
    local include_systemd_services=("swaybg" "swayidle" "swaync_auto")
    mkdir -p ${HOME}/.config/systemd/user
    for serv in "${include_systemd_services[@]}"; do
        cp -ruv "dotconfig/systemd/user/${serv}.service" "${HOME}/.config/systemd/user/${serv}.service"
    done
    
    log "[waybar] Reloading services..."
    systemctl --user daemon-reload
    systemctl --user add-wants niri.service swaybg.service
    systemctl --user add-wants niri.service swaync_auto.service
    systemctl --user add-wants niri.service vicinae.service
    
    
    pkill waybar
    niri msg action spawn-sh -- "waybar"
    
    pkill swaync
    systemctl --user restart --now swaync_auto.service
    
    systemctl --user restart --now swaybg.service
    systemctl --user restart --now vicinae.service
}


deploy_kitty(){    
    if command -v kitty > /dev/null 2>&1; then
        log "[kitty] Found kitty!"
        read -p "Use kitty? [Y/n] " answer
        case "$answer" in
            [Nn]*)
                log "[kitty] Skipping kitty deployment as per user choice."
                return 0
                ;;
            *)
                log "[kitty] Proceeding with kitty deployment..."
                ;;
        esac

        log "[kitty] Copying files..."
        local include_dirs=("kitty")
        for dir in "${include_dirs[@]}"; do
            cp -ruv dotconfig/$dir $HOME/.config/
        done

        log "[kitty] Applying related settings..."
        sed -i 's/Open a Terminal: alacritty/Open a Terminal: kitty/; s/spawn "alacritty"/spawn "kitty"/' $HOME/.config/niri/config.kdl
        sed -i 's/app-id="Alacritty"/app-id="kitty"/g' $HOME/.config/niri/config.kdl
    else
        log "[kitty] kitty not found!"
    fi
}


deploy_mpd() {
    local include_dirs=("mpd")
    deploy_dotconfig_dirs "mpd" include_dirs
    
    
    local MUSIC_DIRECTORY=$(get_config_value "MUSIC_DIRECTORY" "Enter your MUSIC_DIRECTORY for mpd: ")
    local parent=$(dirname "$MUSIC_DIRECTORY")
    local targetfolder=$(basename "$MUSIC_DIRECTORY")
    sed -i "s#MUSIC_DIRECTORY#${parent}#g" "$HOME/.config/mpd/mpd.conf"
    mkdir -p $(cat "$HOME/.config/mpd/mpd.conf" | grep playlist_directory | awk '{print $2}' | sed 's/\"//g' | sed "s#~#${HOME}#g")
    mpd
    mpc clear
    mpc add "${targetfolder}"
    mpc update
    mpc shuffle
    mpc save "${targetfolder}"
    mpc load "${targetfolder}"
}

deploy_ncmpcpp() {
    local include_dirs=("ncmpcpp")
    deploy_dotconfig_dirs "ncmpcpp" include_dirs
    
    
    local MUSIC_DIRECTORY=$(get_config_value "MUSIC_DIRECTORY" "Enter your MUSIC_DIRECTORY for mpd: ")
    sed -i "s#MUSIC_DIRECTORY#${MUSIC_DIRECTORY}#g" "$HOME/.config/ncmpcpp/config"
}

deploy_cava() {
    local include_dirs=("cava")
    deploy_dotconfig_dirs "cava" include_dirs
    local MUSIC_DIRECTORY=$(get_config_value "MUSIC_DIRECTORY" "Enter your MUSIC_DIRECTORY for mpd: ")
    sed -i "s#MUSIC_DIRECTORY#${MUSIC_DIRECTORY}#g" "$HOME/.config/ncmpcpp/config"
}

fix_font() {
    local include_dirs=("fontconfig")
    deploy_dotconfig_dirs "fontconfig" include_dirs
    rm -rv "$HOME/.cache/fontconfig/*"
    fc-cache -fv
}

fix_xdg_portal() {
    local include_dirs=("xdg-desktop-portal")
    deploy_dotconfig_dirs "fix_xdg_portal" include_dirs
    systemctl --user restart --now xdg-desktop-portal
}

cursor_patch(){
    THEME_CURSOR=$(get_config_value "THEME_CURSOR" "Enter your THEME_CURSOR (e.g. Banana): ")
    THEME_CURSOR_SIZE=$(get_config_value "THEME_CURSOR_SIZE" "Enter your THEME_CURSOR_SIZE (e.g. 24): ")
    cp -ruv dotconfig/niri/config.kdl ~/.config/niri/config.kdl
    
    log "[cursor_patch] Patching ~/.zshrc for cursor theme and size"
    sed -i "s/^gtk-cursor-theme-name.*/gtk-cursor-theme-name=\"$THEME_CURSOR\"/" $HOME/.gtkrc-2.0
    sed -i "s/^Gtk\/CursorThemeName.*/Gtk\/CursorThemeName \"$THEME_CURSOR\"/" $HOME/.config/xsettingsd/xsettingsd.conf
    sed -i "s/^gtk-cursor-theme-name.*/gtk-cursor-theme-name=$THEME_CURSOR/" $HOME/.config/gtk-4.0/settings.ini
    sed -i "s/^gtk-cursor-theme-name.*/gtk-cursor-theme-name=$THEME_CURSOR/" $HOME/.config/gtk-3.0/settings.ini
    sed -i "s/^    XCURSOR_THEME.*/    XCURSOR_THEME \"$THEME_CURSOR\"/" dotconfig/niri/config.kdl
    sed -i "s/^    XCURSOR_SIZE.*/    XCURSOR_SIZE \"$THEME_CURSOR_SIZE\"/" dotconfig/niri/config.kdl
    sed -i "s/^    xcursor-theme.*/    xcursor-theme \"$THEME_CURSOR\"/" dotconfig/niri/config.kdl
    sed -i "s/^    xcursor-size.*/    xcursor-size $THEME_CURSOR_SIZE/" dotconfig/niri/config.kdl
    sed -i "s/^export XCURSOR_THEME=.*/export XCURSOR_THEME=\"$THEME_CURSOR\"/" $HOME/.zshrc
    sed -i "s/^export XCURSOR_SIZE=.*/export XCURSOR_SIZE=\"$THEME_CURSOR_SIZE\"/" $HOME/.zshrc
}

surface_patch(){
    PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if [[ "$PRODUCT_NAME" == *"Surface"* ]]; then
        log "[surface_patch] This is a Surface device: $PRODUCT_NAME, now running Surface patch..."
        CONFIG_FILE_NIRI="$HOME/.config/niri/config.kdl"
        CONFIG_FILE_WAYBAR="$HOME/.config/waybar/config.jsonc"
        
        log "[surface_patch] Patching ~/.config/niri/config.kdl ..."
        sed -i 's/mode "1920x1080@60"/mode "1920x1280@60"/' "$CONFIG_FILE_NIRI"
        sed -i 's/scale 1.125/scale 1.25/' "$CONFIG_FILE_NIRI"
        sed -i 's/position x=1080 y=0/position x=1280 y=0/' "$CONFIG_FILE_NIRI"
        log "[surface_patch] Patching ~/.config/waybar/config.jsonc ..."
        sed -i '/"wlr\/taskbar"$/{/[{]/!d}' "$CONFIG_FILE_WAYBAR"
        sed -i 's/"tray"\,/"tray"/' "$CONFIG_FILE_WAYBAR"
        sed -i 's/"artist-len": 7\,/"artist-len": 5\,/' "$CONFIG_FILE_WAYBAR"
        sed -i "s/^    \"artist-len\": .*/    \"artist-len\": 5,/g" "$CONFIG_FILE_WAYBAR"
        sed -i "s/^    \"title-len\": .*/    \"title-len\": 5,/g" "$CONFIG_FILE_WAYBAR"
    fi
}


# Start here.

# Unit re-deploy
# mpd
if [[ " $@ " =~ " --mpdonly " ]]; then
    if command -v mpd > /dev/null 2>&1; then
        log "[mpdonly] Found mpd! Now apply related settings..."
        log "[mpdonly] Stopping services..."
        services=("mpd" "ncmpcpp" "cava")
        for s in "${services[@]}"; do
            killall $s
            systemctl --user stop --now "$s"
            systemctl --user disable --now "$s"
        done
        log "[mpdonly] Deploying files..."
        deploy_mpd
        deploy_ncmpcpp
        deploy_cava
    else
        log "[mpdonly] mpd not found!"
    fi
    exit 0
fi

# fontconfig
if [[ " $@ " =~ " --fix-font " ]]; then
    fix_font
    exit 0
fi

# niri
if [[ " $@ " =~ " --nirionly " ]]; then
    rm -rv "$HOME/.config/niri"
    cp -ruv dotconfig/niri "$HOME/.config"
    THEME_CURSOR=$(get_config_value "THEME_CURSOR" "Enter your THEME_CURSOR (e.g. Banana): ")
    THEME_CURSOR_SIZE=$(get_config_value "THEME_CURSOR_SIZE" "Enter your THEME_CURSOR_SIZE (e.g. 24): ")
    sed -i "s/^    XCURSOR_THEME.*/    XCURSOR_THEME \"$THEME_CURSOR\"/" dotconfig/niri/config.kdl
    sed -i "s/^    XCURSOR_SIZE.*/    XCURSOR_SIZE \"$THEME_CURSOR_SIZE\"/" dotconfig/niri/config.kdl
    sed -i "s/^    xcursor-theme.*/    xcursor-theme \"$THEME_CURSOR\"/" dotconfig/niri/config.kdl
    sed -i "s/^    xcursor-size.*/    xcursor-size $THEME_CURSOR_SIZE/" dotconfig/niri/config.kdl
    if command -v qs > /dev/null 2>&1; then
        log "[nirionly] Running patch for noctalia..."
        log "[nirionly] Detected noctalia, using noctalia config."
        sed -i "s/^spawn-at-startup \"waybar\".*/\/\/spawn-at-startup \"waybar\"/" $HOME/.config/niri/config.kdl
        sed -i 's/^    Super+Alt+L.*/    Super+Alt+L hotkey-overlay-title="Lock the Screen: noctalia-shell" { spawn-sh "qs -c noctalia-shell ipc call lockScreen lock"; }/' $HOME/.config/niri/config.kdl
        sed -i 's/vicinae toggle/qs -c noctalia-shell ipc call launcher clipboard/g' $HOME/.config/niri/config.kdl
        sed -i 's/wallpaper\$/noctalia-overview\*/g' $HOME/.config/niri/config.kdl
    fi
    surface_patch
    deploy_kitty
    exit 0
fi


# kitty
if [[ " $@ " =~ " --kittyonly " ]]; then
    rm -rv "$HOME/.config/kitty"
    deploy_kitty
    exit 0
fi


# cursor
if [[ " $@ " =~ " --cursoronly " ]]; then
    cursor_patch
    if command -v qs > /dev/null 2>&1; then
        log "[cursoronly] Running patch for noctalia..."
        log "[cursoronly] Detected noctalia, using noctalia config."
        sed -i "s/^spawn-at-startup \"waybar\".*/\/\/spawn-at-startup \"waybar\"/" $HOME/.config/niri/config.kdl
        sed -i 's/^    Super+Alt+L.*/    Super+Alt+L hotkey-overlay-title="Lock the Screen: noctalia-shell" { spawn-sh "qs -c noctalia-shell ipc call lockScreen lock"; }/' $HOME/.config/niri/config.kdl
        sed -i 's/vicinae toggle/qs -c noctalia-shell ipc call launcher clipboard/g' $HOME/.config/niri/config.kdl
        sed -i 's/wallpaper\$/noctalia-overview\*/g' $HOME/.config/niri/config.kdl
    fi
    exit 0
fi


# fix portal
if [[ " $@ " =~ " --fix-portal " ]]; then
    fix_xdg_portal
    exit 0
fi


# Re-deploy all stuffs.
log "[OVERALL] Stopping services..."
services=("noctalia" "swaybg" "swaync_auto" "swaync" "vicinae" "waybar" "qs" "mpd" "ncmpcpp" "cava")
for s in "${services[@]}"; do
    killall $s
    systemctl --user stop --now "$s"
    systemctl --user disable --now "$s"
done


# Desktop and status bar deployment
log "[OVERALL] Running clean deployment..."
log "[OVERALL] Removing files..."
for f in $(ls -d dotconfig/*/ | sed 's#dotconfig/##')
do
    rm -rv "$HOME/.config/${f}"
done
for f in $(ls -d deprecated/*/ | sed 's#deprecated/##')
do
    rm -rv "$HOME/.config/${f}"
done


# Music player deployment
if command -v mpd > /dev/null 2>&1; then
    log "[MPD Prober] Found mpd! Now apply related settings..."
    deploy_mpd
    deploy_ncmpcpp
    deploy_cava
fi


cursor_patch
fix_font

if [ ! -f ~/.config/menus/applications.menu ]; then
    log "[Patcher: applications.menu] Patching applications.menu for dolphin..."
    ln -sf /etc/xdg/menus/plasma-applications.menu ~/.config/menus/applications.menu
fi


if command -v qs > /dev/null 2>&1; then
    log "[Status Bar Prober] Detected noctalia, using noctalia config."
    if ! command -v matugen > /dev/null 2>&1; then
        log "[Status Bar Prober] WARNING: matugen not found! This is an optional dependency for dynamic color working with noctalia!"
    fi
    if [[ " $@ " =~ " --waybar " ]]; then
        log "[Status Bar Prober] Waybar param detected, using waybar config."
        deploy_waybar
    else
        deploy_noctalia
    fi
else
    log "[Status Bar Prober] Noctalia not found, using waybar config."
    deploy_waybar
fi

deploy_kitty

fix_xdg_portal
surface_patch

log "!!! Remember to run source ~/.zshrc then! !!!"
log "Enjoy!"
