#!/bin/bash

# =============  CHANGE YOUR CURSOR THEME NAME HERE  =============
THEME_CURSOR="Banana"
THEME_CURSOR_SIZE="24"


log() {
    local GREEN='\033[0;32m'
    local NC='\033[0m'
    if [ "$1" ]; then
        echo -e "${GREEN}[$(date)] - $*${NC}"
    fi
}


CONFIG_LOCATION=""
handle_config_weather() {
    local config_file="config.txt"
    local script_dir=$(dirname "$(readlink -f "$0")")
    
    if [[ -f "$config_file" ]]; then
        echo "Found Config: $config_file"
        source "$config_file"
        echo "Got LOCATION: $LOCATION"
    else
        echo "Config file $config_file does not exist!"
        read -p "Enter your LOCATION for weather: " user_input
        
        user_input_lower=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')
        LOCATION=$(echo "$user_input_lower" | sed 's/^\(.\)/\U\1/')
        
        echo "LOCATION=$LOCATION" > "$config_file"
        echo "Saved LOCATION=$LOCATION to $config_file"
    fi
    
    CONFIG_LOCATION="$LOCATION"
}



deploy_noctalia() {
    handle_config_weather
    log "Copying files..."
    exclude_dirs=("systemd" "waybar")
    for dir in dotconfig/*/; do
        dir_name="${dir%/}"

        exclude=0
        for exclude_dir in "${exclude_dirs[@]}"; do
            if [[ "$dir_name" == "$exclude_dir" ]]; then
                exclude=1
                break
            fi
        done

        if [[ $exclude -eq 0 ]]; then
            cp -ruv "$dir_name" $HOME/.config/
        else
            echo "Skipping exclude dir: $dir_name"
        fi
    done

    log "Reloading services..."
    systemctl --user daemon-reload
    systemctl --user add-wants niri.service noctalia.service

    niri msg action spawn-sh -- "qs -c noctalia-shell > /dev/null 2>&1"
    sed -i "s/\"name\": \"LOCATION\"/\"name\": \"$CONFIG_LOCATION\"/gq" "$HOME/.config/noctalia/settings.json"
    sed -i "s/USERNAME/$(whoami)/g" "$HOME/.config/noctalia/settings.json"
    sed -i "s/^spawn-at-startup \"waybar\".*/\/\/spawn-at-startup \"waybar\"/" $HOME/.config/niri/config.kdl
}

deploy_waybar() {
    log "Copying files..."
    exclude_dirs=("systemd" "noctalia")
    for dir in dotconfig/*/; do
        dir_name="${dir%/}"

        exclude=0
        for exclude_dir in "${exclude_dirs[@]}"; do
            if [[ "$dir_name" == "$exclude_dir" ]]; then
                exclude=1
                break
            fi
        done

        if [[ $exclude -eq 0 ]]; then
            cp -ruv "$dir_name" $HOME/.config/
        else
            echo "Skipping exclude dir: $dir_name"
        fi
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


log "Stopping services..."
services=("noctalia" "swaybg" "swaync_auto" "vicinae" "waybar" "qs")
for s in "${services[@]}"; do
  systemctl --user stop --now "$s"
  systemctl --user disable --now "$s"
  killall $s
done


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
    sed -i "s/^    \"artist-len\": .*/    \"artist-len\": 5,/" "$CONFIG_FILE_WAYBAR"
    sed -i "s/^    \"title-len\": .*/    \"title-len\": 5,/" "$CONFIG_FILE_WAYBAR"
fi


log "Enjoy!"
