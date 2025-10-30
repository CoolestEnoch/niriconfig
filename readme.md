# Prerequirements
After you installed `sddm` and necessary applications from KDE Plasma like `dolphin plasma-systemmonitor systemsettings konsole okular`, then install packages below:
``` shell
sudo pacman -S --needed niri alacritty fuzzel swaylock swayidle waybar swaybg xwayland-satellite brightnessctl 
```
If you want to use `waybar`, please install `network-manager-applet` and `blueman` to control these two hardware.

# How to apply?
``` shell
cd dotconfig && chmod +x deploy.sh && ./deploy.sh
```
Then log out your session, choose `niri` instead of `KDE Plasma(Wayland)` in the left-bottom corner, enter your password and login.


If you want to run a clean-deployment, please add `--clean` param to the scipt.
e.g.
``` shell
./deploy.sh --clean
```


If you have `noctalia` installed on your computer, it will use it instead of `waybar`. If you want to force use `waybar` instead of `noctalia`, please add `--waybar` param to the script.
e.g.
``` shell
./deploy.sh --waybar
```
To install `noctalia`, please run this:
``` shell
paru -Sy noctalia-shell matugen-bin cliphist
```
> Note:
> `matugen` is an optional dependency to extract color from your wallpaper, just like the Monet Color introduced in Android 12. See also: [dynamic colors (Android Developers)](https://developer.android.google.cn/develop/ui/views/theming/dynamic-colors)
> `cliphist` is an optional dependency for noctalia to display clipboard history. If you have installed `vicinae` in section Clipboard History, it will be disabled by `deploy.sh`.



# Music Player Support
Now support `mpc` and `mpris` protocol player, and all will be configured by `deploy.sh`.
`mpris` are supported natively and you can use it out-of-box.


To use `mpd`, install dependencies below:
``` shell
sudo pacman -S ncmpcpp mpd wildmidi timidity++ mpc
```


# How to change fonts?
Download font from KDE Theme Store or other site, uncompress it to `~/.icons`. Then remember the cursor theme's name, open the `deploy.sh` and change the `THEME_CURSOR` to theme's name, and `THEME_CURSOR_SIZE` to cursor's size \(default is 24\) value to what you want, then rerun `deploy.sh` again to live patch cursor theme settings.


# Default wallpaper
Default desktop wallpaper is located at `~/Pictures/wallpaper/wallpaper_desktop.png` (or edit the configuration file `dotfiles/systemd/user/swaybg.service`), default lock-screen wallpaper is located at `~/Pictures/wallpaper/wallpaper_lock.png` (or edit the configuration file `dotconfig/swaylock/config`).


# Clipboard History
I'm using `vicinae` to toggle history, and the shortcut key is `Super+X`.
Requirement:
``` shell
paru -S vicinae-bin
```


# Issues about WeChat (no popout window for right-click)
Wrap the WeChat start command with `gamescope`, refer to [this](https://wiki.archlinux.org/title/Gamescope).
You need to have `mesa` driver insatlled, refer to [this](https://wiki.archlinux.org/title/Intel_graphics).
In general, just run this to install packages.
``` shell
sudo pacman -S gamescope mesa vulkan-intel
```

Then run `your_program` in `gamescope` with this command:
``` shell
# Direct run
gamescope -- your_progrom
# Run with specific resolution
gamescope -W 1920 -H 1080 -r 60 -- your_program
```
If you occur into problems with `wayland`, add this param:
``` shell
--expose-wayland
```



# Thanks
[Niri GitHub 仓库](https://github.com/YaLTeR/niri)
****
[XF86 Keyboard Symbols](https://wiki.linuxquestions.org/wiki/XF86_keyboard_symbols)
[kznleaf - 无限平铺窗口管理器——niri在 ArchLinux 上的安装与配置](https://kznleaf.top/2025/09/18/niri%E5%AE%89%E8%A3%85%E4%B8%8E%E9%85%8D%E7%BD%AE)
[woioeow/hyprland-dotfiles GitHub仓库](https://github.com/woioeow/hyprland-dotfiles)
[Archlinux Forums - How to set up Polkit to allow Dolphin to mount different Partitions?](https://bbs.archlinux.org/viewtopic.php?id=288823)
[ArchWiki - polkit](https://wiki.archlinux.org/title/Polkit#Authentication_agents)
[ArchWiki - XDG MIME Applications](https://wiki.archlinux.org/title/XDG_MIME_Applications#Empty_MIME_associations_/_open_with_menu_in_KDE)
[Swaylock GitHub 仓库](https://github.com/swaywm/swaylock)
[Swaylock 参数解释 GitHub 仓库](https://github.com/swaywm/swaylock/blob/master/swaylock.1.scd)

