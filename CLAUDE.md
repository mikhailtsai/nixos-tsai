# NixOS Configuration - Claude Context

## System Overview
- **User**: leet (Mikhail Tsai)
- **Hostname**: nixos
- **Flake-based configuration**
- **Desktop**: Hyprland (Wayland)
- **Hardware**: Intel CPU + NVIDIA RTX 4080 (Ada Lovelace) with PRIME sync

## Commands

### Rebuild system (ALWAYS use flake)
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

### Test configuration without switching
```bash
sudo nixos-rebuild test --flake /etc/nixos#nixos
```

### Update flake inputs
```bash
nix flake update /etc/nixos
```

## File Structure
- `flake.nix` - Flake definition and inputs
- `configuration.nix` - Main system configuration
- `hardware-configuration.nix` - Auto-generated hardware config (don't edit)
- `home.nix` - Home Manager configuration
- `home/hyprland.nix` - Hyprland window manager config
- `home/waybar.nix` - Waybar status bar config

## Hardware Notes
- **GPU Setup**: PRIME sync mode (NVIDIA primary, Intel for internal display passthrough)
- **HDMI**: Connected to NVIDIA GPU, works at boot/login
- **Laptop display**: Works via NVIDIA → Intel passthrough
- **Primary usage**: 95% docked with HDMI, 5% mobile

## User Preferences
- Prefers concise solutions
- Russian comments in config files are OK
- Uses Hyprland + Waybar + Kitty terminal
- Gaming setup with Steam, Lutris, Heroic
- Audio production with REAPER, Focusrite interface (realtime audio configured)
