{ config, pkgs, lib, vars, ... }:

{
  # ── Ollama с поддержкой CUDA на NVIDIA RTX 4080 Laptop ───────────────────
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "127.0.0.1";
    port = 11434;

    environmentVariables = {
      # Flash Attention: критично для 12GB VRAM — снижает потребление KV-кэша и ускоряет инференс
      OLLAMA_FLASH_ATTENTION = "1";
      # Держим модель в памяти 60 минут, чтобы не перезагружать веса при каждом запросе
      OLLAMA_KEEP_ALIVE = "60m";
      # 1 поток генерации для предотвращения дублирования KV-кэша в VRAM
      OLLAMA_NUM_PARALLEL = "1";
    };
  };

  # Доступ к локальным моделям в ~/Models:
  # По умолчанию services.ollama имеет ProtectHome = true, что запрещает чтение /home.
  # Переключаем в read-only и явно открываем ~/Models для чтения сервисом.
  systemd.services.ollama.serviceConfig = {
    ProtectHome = lib.mkForce "read-only";
    ReadOnlyPaths = [ "/home/${vars.username}/Models" ];
  };

  # ── OpenCode (Desktop GUI + CLI) ──────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    opencode-desktop  # Графический интерфейс Electron под Wayland/Hyprland
    opencode          # Терминальный CLI агент
  ];
}
