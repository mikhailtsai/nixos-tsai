# NixOS Configuration - Mikhail Tsai

Декларативная конфигурация NixOS с Hyprland (Wayland) и Home Manager.

## Структура проекта

```
├── flake.nix                   # Точка входа, определяет две конфигурации
├── configuration.nix           # Основная системная конфигурация
├── home.nix                    # Home Manager (импортирует модули)
├── vmware.nix                  # VMware-специфичные настройки (только для тестирования)
├── hardware-configuration.nix  # Генерируется на целевой системе
└── home/
    ├── hyprland.nix            # Hyprland + hypridle + hyprlock + hyprpaper
    └── waybar.nix              # Waybar конфиг + стили
```

## Конфигурации

| Конфигурация | Команда | Использование |
|--------------|---------|---------------|
| `nixos` | `--flake .#nixos` | Реальное железо (ноутбук) |
| `nixos-vmware` | `--flake .#nixos-vmware` | Тестирование в VMware |

## Установка

### 1. Загрузка с NixOS ISO

Скачай [NixOS Minimal ISO](https://nixos.org/download/) и загрузись с него.

### 2. Подготовка диска

```bash
# Разметка диска (UEFI)
sudo parted /dev/sda -- mklabel gpt
sudo parted /dev/sda -- mkpart ESP fat32 1MB 512MB
sudo parted /dev/sda -- set 1 esp on
sudo parted /dev/sda -- mkpart primary 512MB 100%

# Форматирование
sudo mkfs.fat -F 32 -n BOOT /dev/sda1
sudo mkfs.ext4 -L nixos /dev/sda2

# Монтирование
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/BOOT /mnt/boot
```

### 3. Включение Flakes (на Live ISO)

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
```

### 4. Клонирование конфигурации

```bash
nix-shell -p git
sudo git clone https://github.com/YOUR_USERNAME/nixos-tsai.git /mnt/etc/nixos
sudo chown -R $(whoami):users /mnt/etc/nixos
cd /mnt/etc/nixos
```

### 5. Генерация hardware-configuration.nix

```bash
nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
git add hardware-configuration.nix
```

### 6. Установка

```bash
# Для реального железа
sudo nixos-install --flake .#nixos

# Для VMware
sudo nixos-install --flake .#nixos-vmware
```

### 7. Перезагрузка

```bash
sudo reboot
```

## Обновление системы

```bash
cd /etc/nixos

# Обновить flake.lock
sudo nix flake update

# Применить конфигурацию
sudo nixos-rebuild switch --flake .#nixos
```

## Горячие клавиши Hyprland

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
| `Super + стрелки` | Переключить фокус |
| `Print` | Скриншот области |
| `Shift + Print` | Скриншот всего экрана |
| `Alt + Shift` | Переключить раскладку (us/ru) |

## Что включено

- **WM**: Hyprland (Wayland tiling compositor)
- **Bar**: Waybar
- **Launcher**: Wofi
- **Terminal**: Kitty (FiraCode Nerd Font)
- **Audio**: PipeWire
- **Lock**: Hyprlock + Hypridle
- **DM**: greetd + tuigreet

## После установки

1. Добавь обои: `~/.config/hypr/wallpaper.png`
2. Настрой git email в `home.nix`
3. Установи дополнительные пакеты по необходимости
