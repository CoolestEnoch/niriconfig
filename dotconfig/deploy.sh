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


# =============  CHANGE YOUR CURSOR THEME NAME HERE  =============
THEME_CURSOR="Banana"
THEME_CURSOR_SIZE="24"
echo "Patching ~/.zshrc for cursor theme and size"
sed -i "s/^gtk-cursor-theme-name.*/gtk-cursor-theme-name=\"$THEME_CURSOR\"/" $HOME/.gtkrc-2.0
sed -i "s/^Gtk\/CursorThemeName.*/Gtk\/CursorThemeName \"$THEME_CURSOR\"/" $HOME/.config/xsettingsd/xsettingsd.conf
sed -i "s/^gtk-cursor-theme-name.*/gtk-cursor-theme-name=$THEME_CURSOR/" $HOME/.config/gtk-4.0/settings.ini
sed -i "s/^gtk-cursor-theme-name.*/gtk-cursor-theme-name=$THEME_CURSOR/" $HOME/.config/gtk-3.0/settings.ini
sed -i "s/^    XCURSOR_THEME.*/    XCURSOR_THEME \"$THEME_CURSOR\"/" niri/config.kdl
sed -i "s/^    XCURSOR_SIZE.*/    XCURSOR_SIZE \"$THEME_CURSOR_SIZE\"/" niri/config.kdl
sed -i "s/^    xcursor-theme.*/    xcursor-theme \"$THEME_CURSOR\"/" niri/config.kdl
sed -i "s/^    xcursor-size.*/    xcursor-size $THEME_CURSOR_SIZE/" niri/config.kdl
sed -i "s/^export XCURSOR_THEME=.*/export XCURSOR_THEME=\"$THEME_CURSOR\"/" $HOME/.zshrc
sed -i "s/^export XCURSOR_SIZE=.*/export XCURSOR_SIZE=\"$THEME_CURSOR_SIZE\"/" $HOME/.zshrc


echo "Copying files..."
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
    sed -i 's/"artist-len": 7\,/"artist-len": 5\,/' "$CONFIG_FILE_WAYBAR"
    sed -i "s/^    \"artist-len\": .*/    \"artist-len\": 5,/" "$CONFIG_FILE_WAYBAR"
    sed -i "s/^    \"title-len\": .*/    \"title-len\": 5,/" "$CONFIG_FILE_WAYBAR"
fi


echo "Reloading services..."
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



echo "!!! Remember to run source ~/.zshrc then! !!!"
echo "Enjoy!"
