#!/bin/bash

if [[ " $@ " =~ " --clean " ]]; then
    echo "Running clean deployment..."
    for f in $(ls -d */ | sed 's#/##')
    do
        rm -rv "$HOME/.config/${f}"
    done
fi

cp -ruv * $HOME/.config


systemctl --user daemon-reload
systemctl --user add-wants niri.service swaybg.service
systemctl --user add-wants niri.service swaync_auto.service


pkill waybar
systemctl --user restart --now waybar.service

pkill swaync
systemctl --user restart --now swaync.service
swaync-client --reload-config
