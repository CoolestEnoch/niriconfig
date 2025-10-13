# Prerequirements
After you installed `sddm` and necessary applications from KDE Plasma like `dolphin plasma-systemmonitor systemsettings konsole okular`, then install packages below:
``` shell
sudo pacman -S --needed niri alacritty fuzzel swaylock swayidle waybar swaybg xwayland-satellite
```

# How to apply?
``` shell
cd dotconfig && chmod +x deploy.sh && ./deploy.sh
```
Then log out your session, choose `niri` instead of `KDE Plasma(Wayland)` in the left-bottom corner, enter your password and login.


# Default wallpaper
Default desktop wallpaper is located at `~/Pictures/wallpaper/wallpaper_desktop.png` (or edit the configuration file `dotfiles/systemd/user/swaybg.service`), default lock-screen wallpaper is located at `~/Pictures/wallpaper/wallpaper_lock.png` (or edit the configuration file `dotconfig/swaylock/config`).



# Thanks
[Niri GitHub 仓库](https://github.com/YaLTeR/niri)
****
[kznleaf - 无限平铺窗口管理器——niri在 ArchLinux 上的安装与配置](https://kznleaf.top/2025/09/18/niri%E5%AE%89%E8%A3%85%E4%B8%8E%E9%85%8D%E7%BD%AE)
[woioeow/hyprland-dotfiles GitHub仓库](https://github.com/woioeow/hyprland-dotfiles)
[Archlinux Forums - How to set up Polkit to allow Dolphin to mount different Partitions?](https://bbs.archlinux.org/viewtopic.php?id=288823)
[ArchWiki - polkit](https://wiki.archlinux.org/title/Polkit#Authentication_agents)
[ArchWiki - XDG MIME Applications](https://wiki.archlinux.org/title/XDG_MIME_Applications#Empty_MIME_associations_/_open_with_menu_in_KDE)
[Swaylock GitHub 仓库](https://github.com/swaywm/swaylock)
[Swaylock 参数解释 GitHub 仓库](https://github.com/swaywm/swaylock/blob/master/swaylock.1.scd)

