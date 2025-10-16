#!/bin/bash

if [[ " $@ " =~ " --clean " ]]; then
    echo "Running clean deployment..."
    for f in $(ls -d */ | sed 's#/##')
    do
        rm -rv "$HOME/.config/${f}"
    done
else
    echo "Run with --clean param to start a clean deployment."
    echo ""
fi

cp -ruv * $HOME/.config

PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
if [[ "$PRODUCT_NAME" == *"Surface"* ]]; then
    echo "This is a Surface device: $PRODUCT_NAME, now running Surface patch..."
    CONFIG_FILE_NIRI="$HOME/.config/niri/config.kdl"
    CONFIG_FILE_WAYBAR="$HOME/.config/waybar/config.jsonc"
    
    echo "Patching ~/.config/niri/config.kdl ..."
    sed -i 's/mode "1920x1080@60"/mode "1920x1280@60"/' "$CONFIG_FILE_NIRI"
    sed -i 's/scale 1.125/scale 1.25/' "$CONFIG_FILE_NIRI"
    sed -i 's/position x=1080 y=0/position x=1280 y=0/' "$CONFIG_FILE_NIRI"
    echo "Patching ~/.config/waybar/config.jsonc ..."
    sed -i '/"wlr\/taskbar"$/{/[{]/!d}' "$CONFIG_FILE_WAYBAR"
    sed -i 's/"tray"\,/"tray"/' "$CONFIG_FILE_WAYBAR"
    echo "Patching done."
fi


systemctl --user daemon-reload
systemctl --user add-wants niri.service swaybg.service
systemctl --user add-wants niri.service swaync_auto.service
systemctl --user add-wants niri.service vicinae.service


pkill waybar
systemctl --user restart --now waybar.service

pkill swaync
systemctl --user restart --now swaync_auto.service

systemctl --user restart --now swaybg.service
systemctl --user restart --now vicinae.service