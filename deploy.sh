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


deploy_noctalia() {
    log "[noctalia] Copying files..."
    local config_file="config.txt"
    local script_dir=$(dirname "$(readlink -f "$0")")
    local LOCATION_WEATHER=$(get_config_value "LOCATION_WEATHER" "Enter your LOCATION for weather: ")
        
    
    log "Copying files..."
    local include_dirs=("niri" "noctalia")
    for dir in "${include_dirs[@]}"; do
        cp -ruv dotconfig/$dir $HOME/.config/
    done
    local include_systemd_services=("noctalia")
    mkdir -p ${HOME}/.config/systemd/user
    for serv in "${include_systemd_services[@]}"; do
        cp -ruv "dotconfig/systemd/user/${serv}.service" "${HOME}/.config/systemd/user/${serv}.service"
    done

    log "Reloading services..."
    systemctl --user daemon-reload
    systemctl --user add-wants niri.service noctalia.service
    systemctl --user mask swaync.service

    niri msg action spawn-sh -- "qs -c noctalia-shell > /dev/null 2>&1"
    sed -i "s/\"name\": \"LOCATION\"/\"name\": \"$LOCATION_WEATHER\"/g" "$HOME/.config/noctalia/settings.json"
    sed -i "s/USERNAME/$(whoami)/g" "$HOME/.config/noctalia/settings.json"
    sed -i "s/^spawn-at-startup \"waybar\".*/\/\/spawn-at-startup \"waybar\"/" $HOME/.config/niri/config.kdl
    sed -i 's/^    Super+Alt+L.*/    Super+Alt+L hotkey-overlay-title="Lock the Screen: noctalia-shell" { spawn-sh "qs -c noctalia-shell ipc call lockScreen toggle"; }/' $HOME/.config/niri/config.kdl
    sed -i 's/vicinae toggle/qs -c noctalia-shell ipc call launcher clipboard/g' $HOME/.config/niri/config.kdl
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

    log "Reloading services..."
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


deploy_mpd() {
    log "[mpd] Copying files..."
    local include_dirs=("mpd")
    for dir in "${include_dirs[@]}"; do
        cp -ruv dotconfig/$dir $HOME/.config/
    done


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
    log "[ncmpcpp] Copying files..."
    include_dirs=("ncmpcpp")
    for dir in "${include_dirs[@]}"; do
        cp -ruv dotconfig/$dir $HOME/.config/
    done


    local MUSIC_DIRECTORY=$(get_config_value "MUSIC_DIRECTORY" "Enter your MUSIC_DIRECTORY for mpd: ")
    sed -i "s#MUSIC_DIRECTORY#${MUSIC_DIRECTORY}#g" "$HOME/.config/ncmpcpp/config"
}

log "Stopping services..."
services=("noctalia" "swaybg" "swaync_auto" "swaync" "vicinae" "waybar" "qs" "mpd" "ncmpcpp")
for s in "${services[@]}"; do
  killall $s
  systemctl --user stop --now "$s"
  systemctl --user disable --now "$s"
done


# Desktop and status bar deployment
if [[ " $@ " =~ " --clean " ]]; then
    log "Running clean deployment..."
    for f in $(ls -d dotconfig/*/ | sed 's#dotconfig/##')
    do
        rm -rv "$HOME/.config/${f}"
    done
else
    log "Run with --clean param to start a clean deployment."
    echo ""
fi


# Music player deployment
if command -v mpd > /dev/null 2>&1; then
    log "Found mpd! Now apply related settings..."
    deploy_mpd
    deploy_ncmpcpp
fi


THEME_CURSOR=$(get_config_value "THEME_CURSOR" "Enter your THEME_CURSOR (e.g. Banana): ")
THEME_CURSOR_SIZE=$(get_config_value "THEME_CURSOR_SIZE" "Enter your THEME_CURSOR_SIZE (e.g. 24): ")

log "Patching ~/.zshrc for cursor theme and size"
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


if command -v qs > /dev/null 2>&1; then
    log "Detected noctalia, using noctalia config."
    if ! command -v matugen > /dev/null 2>&1; then
        log "WARNING: matugen not found! This is an optional dependency for dynamic color working with noctalia!"
    fi
    if [[ " $@ " =~ " --waybar " ]]; then
        log "Waybar param detected, using waybar config."
        deploy_waybar
    else
        log "Run with --clean param to start a clean deployment."
        echo ""
        deploy_noctalia
    fi
else
    log "Noctalia not found, using waybar config."
    deploy_waybar
fi

log "!!! Remember to run source ~/.zshrc then! !!!"



PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
if [[ "$PRODUCT_NAME" == *"Surface"* ]]; then
    log "This is a Surface device: $PRODUCT_NAME, now running Surface patch..."
    CONFIG_FILE_NIRI="$HOME/.config/niri/config.kdl"
    CONFIG_FILE_WAYBAR="$HOME/.config/waybar/config.jsonc"
    
    log "Patching ~/.config/niri/config.kdl ..."
    sed -i 's/mode "1920x1080@60"/mode "1920x1280@60"/' "$CONFIG_FILE_NIRI"
    sed -i 's/scale 1.125/scale 1.25/' "$CONFIG_FILE_NIRI"
    sed -i 's/position x=1080 y=0/position x=1280 y=0/' "$CONFIG_FILE_NIRI"
    log "Patching ~/.config/waybar/config.jsonc ..."
    sed -i '/"wlr\/taskbar"$/{/[{]/!d}' "$CONFIG_FILE_WAYBAR"
    sed -i 's/"tray"\,/"tray"/' "$CONFIG_FILE_WAYBAR"
    sed -i 's/"artist-len": 7\,/"artist-len": 5\,/' "$CONFIG_FILE_WAYBAR"
    sed -i "s/^    \"artist-len\": .*/    \"artist-len\": 5,/g" "$CONFIG_FILE_WAYBAR"
    sed -i "s/^    \"title-len\": .*/    \"title-len\": 5,/g" "$CONFIG_FILE_WAYBAR"
fi


log "Enjoy!"
