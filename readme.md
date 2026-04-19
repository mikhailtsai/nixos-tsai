# NixOS Configuration

Декларативная конфигурация NixOS с Hyprland и Home Manager.

## Структура

```
flake.nix              # Точка входа
configuration.nix      # Системная конфигурация
home.nix               # Home Manager
home/hyprland.nix      # Hyprland + hyprlock + hypridle
home/waybar.nix        # Waybar
vmware.nix             # VMware (для тестирования)
```

## Применение

```bash
# Реальное железо
sudo nixos-rebuild switch --flake .#nixos

# VMware
sudo nixos-rebuild switch --flake .#nixos-vmware
```

## Обновление

```bash
sudo nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

## Горячие клавиши

| Клавиши | Действие |
|---------|----------|
| `Super + Enter` | Терминал (Kitty) |
| `Super + D` | Лаунчер (Wofi) |
| `Super + Q` | Закрыть окно |
| `Super + F` | Полный экран |
| `Super + V` | Плавающее окно |
| `Super + L` | Заблокировать экран |
| `Super + 1-0` | Рабочий стол 1-10 |
| `Super + Shift + 1-0` | Переместить окно |
| `Print` | Скриншот области |
| `Shift + Print` | Скриншот экрана |
| `Alt + Shift` | Переключить раскладку |

## Стек

Hyprland, Waybar, Wofi, Kitty, PipeWire, Hyprlock, greetd
