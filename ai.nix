{ config, pkgs, lib, vars, hermes-agent, ... }:

let
  modelsDir = "/home/${vars.username}/Storage/Models";
  inherit (vars.ai) llamaPort;

  modelsPreset = pkgs.writeText "llama-models.ini" ''
    version = 1

    # ── Общие настройки ──────────────────────────────────────────────────────
    [*]

    # Flash Attention особенно полезен при большом context.
    flash-attn = on

    # llama.cpp сам подгоняет GPU offload под доступные 12 GB VRAM.
    # Если всё не помещается — часть остаётся в системной RAM.
    fit = on

    # Одна agent-сессия = максимум памяти отдаём одному context.
    parallel = 1

    # Уменьшаем пиковое потребление VRAM при обработке prompt.
    # Для нашего сценария большой context важнее максимальной скорости prefill.
    batch-size = 256
    ubatch-size = 128

    cache-type-k = q4_0
    cache-type-v = q4_0

    cache-ram = 4096


    # Через 5 минут idle модель можно полностью выгрузить.
    sleep-idle-seconds = 300

    # ── Qwen3.6 35B-A3B (MoE) ────────────────────────────────────────────────
    #
    # Кандидат на роль orchestrator.
    # MoE: ~3B активных параметров — быстрый, при этом качество 35B.
    #
    # ShapeLearn IQ4_XS (~3.93 bpw, ~17 GB) — часть в 12 GB VRAM,
    # остальное в системной RAM (fit = on).
    [qwen-orch-35b]
    model = ${modelsDir}/Qwen3.6-35B-A3B-ShapeLearn-IQ4_XS.gguf
    ctx-size = 65536

    temperature = 0.2
    top-p = 0.9
    min-p = 0.05

    # ── Qwen 3.8 27B ─────────────────────────────────────────────────────────
    #
    # Основная локальная модель.
    #
    # 64K важнее для OpenCode, чем попытка любой ценой
    # удержать всю модель и KV исключительно в VRAM.
    [qwen-local]
    model = ${modelsDir}/Qwen3.8-27B-ShapeLearn-IQ4_XS.gguf
    ctx-size = 65536

    temperature = 0.2
    top-p = 0.9
    min-p = 0.05


    # ── Ternary Bonsai 2 27B ─────────────────────────────────────────────────
    #
    # 27B в ternary-весах (PTQ1_0, ~1.75 bpw, 5.95 GB) + vision-башня (mmproj).
    # Требует ternary-ядер форка PrismML (пакет llama-cpp-prism) — основной
    # llama.cpp эти файлы не грузит. Сэмплинги — рекомендованные карточкой
    # модели для thinking-режима (top_k=20 обязателен, в GGUF его нет).
    #
    # 192K контекста: модель поддерживает 262144, веса крошечные (~6.3 GB
    # веса + mmproj), KV q4_0 растёт только на full-attention слоях
    # (гибрид SSM/attention: full_attention_interval=4 ⇒ 16 из 64 слоёв) и
    # стоит ~18 KB/токен: 98304 ≈ 1.69 GiB, 196608 ≈ 3.38 GiB.
    # Пик llama-server ~9.9 GiB из 12 GB; не запускать ComfyUI одновременно.
    [bonsai]
    model = ${modelsDir}/Ternary-Bonsai-2-27B-PTQ1_0.gguf
    mmproj = ${modelsDir}/Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf
    ctx-size = 196608

    temperature = 1.0
    top-p = 0.95
    min-p = 0.05
    top-k = 20


    # Other experimental models:

    [hydra]
    model = ${modelsDir}/MN-12B-Hydra-RP-RU.Q5_K_M.gguf
    ctx-size = 32768
    temperature = 0.8
    top-p = 0.9
    min-p = 0.05
    repeat-penalty = 1.07    
  '';


  # ── Полная выгрузка sleeping моделей ──────────────────────────────────────
  unloadSleepingModels = pkgs.writeShellScript "llama-unload-sleeping-models" ''
    set -euo pipefail

    models=$(
      ${pkgs.curl}/bin/curl \
        --fail \
        --silent \
        http://127.0.0.1:${toString llamaPort}/v1/models
    ) || exit 0

    ${pkgs.jq}/bin/jq \
      -r '.data[] | select(.status.value == "sleeping") | .id' \
      <<< "$models" |
      while IFS= read -r model; do

        payload=$(
          ${pkgs.jq}/bin/jq \
            -nc \
            --arg model "$model" \
            '{ model: $model }'
        )

        ${pkgs.curl}/bin/curl \
          --fail \
          --silent \
          -H 'Content-Type: application/json' \
          --data "$payload" \
          http://127.0.0.1:${toString llamaPort}/models/unload \
          >/dev/null
      done
  '';


in
{
  # ── llama.cpp ───────────────────────────────────────────────────────────────
  services.llama-cpp = {
    enable = true;

    # PrismML-форк llama.cpp: ternary-ядра для Bonsai 2, плюс поддержка
    # обычных квантов — весь локальный стек обслуживает один сервер-роутер.
    package = pkgs.llama-cpp-prism;

    settings = {
      host = "127.0.0.1";
      port = llamaPort;

      "models-preset" = modelsPreset;

      # Одновременно загружена максимум одна модель.
      "models-max" = 1;

      # Prometheus-метрики llama-server: панель (home/ai-monitor.nix) берёт
      # оттуда среднюю скорость генерации (tokens_predicted / _seconds).
      metrics = true;
    };
  };


  # ── Доступ к ~/Storage/Models ─────────────────────────────────────────────
  systemd.services.llama-cpp.serviceConfig = {
    ProtectHome = lib.mkForce "read-only";

    ReadOnlyPaths = [
      modelsDir
    ];
  };


  # ── Полный unload sleeping models ─────────────────────────────────────────
  systemd.services.llama-cpp-unload-sleeping = {
    description = "Fully unload sleeping llama.cpp models";

    after = [
      "llama-cpp.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = unloadSleepingModels;
    };
  };


  systemd.timers.llama-cpp-unload-sleeping = {
    wantedBy = [
      "timers.target"
    ];

    timerConfig = {
      OnBootSec = "6min";
      OnUnitActiveSec = "1min";
      Unit = "llama-cpp-unload-sleeping.service";
    };
  };


  # ── Hermes Agent (NousResearch) ─────────────────────────────────────────────
  #
  # Автономный агент NousResearch. Запускаем в контейнерном режиме: unit
  # биндмаунтит /nix/store внутрь контейнера (ro) и стартует gateway из
  # Nix-собранного пакета — хостовый Python 3.14/uv не трогаем, всё изолировано.
  # Сеть у контейнера host-ная, поэтому gateway видит 127.0.0.1:${toString llamaPort}.
  services.hermes-agent = {
    enable = true;

    # Контейнер с образом ubuntu:24.04 (container.backend = docker по умолчанию;
    # virtualisation.docker.enable уже включён в modules/services.nix).
    container.enable = true;

    # Даём текущему пользователю CLI `hermes` в PATH и writable-симлинк
    # ~/.hermes (конфиг/состояние живут в /var/lib/hermes, HERMES_HOME=/var/lib/hermes/.hermes).
    addToSystemPackages = true;
    container.hostUsers = [ vars.username ];

    # Вариант пакета: messaging (+~33 MB к замыканию) вместо default/full.
    # full тяжелее примерно на ~700 MB и тянет voice/tts-premium/matrix/
    # azure/bedrock — здесь они не нужны; недостающие extras контейнер доставит сам.
    # Нужны voice/tts/matrix — переключить на .default (или .tui).
    package = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging;

    # ── Маршрутизация LLM ───────────────────────────────────────────────────
    #
    # Основной маршрут — бесплатная модель через встроенный zen-релей OpenCode:
    # `model.provider` принимает голый id встроенного провайдера (префикс
    # `custom:` нужен только для собственных эндпоинтов), а блоки
    # `providers.<имя>` для встроенных провайдеров не требуются вовсе.
    # settings рендерится через builtins.toJSON в $HERMES_HOME/config.yaml
    # (JSON — это корректный YAML), вложенные attrsets → YAML-ключи 1:1.
    settings = {
      model = {
        provider = "opencode-zen";
        default = "deepseek-v4.1-flash-free";
      };

      # Штатный per-turn failover Hermes: при rate-limit/ошибке сервера/
      # авторизации сессия переключается на платный DeepSeek и возвращается
      # обратно на следующий ход. Для встроенных провайдеров достаточно
      # provider + model (base_url/key_env наследуются); запись без любого
      # из этих полей игнорируется. fallback.min_switch_reset_seconds = 0
      # по умолчанию — переключаемся сразу.
      fallback_providers = [
        {
          provider = "deepseek";
          model = "deepseek-flash";
        }
      ];

      # ── На будущее: OpenCode Go ─────────────────────────────────────────
      # Если появится подписка OpenCode Go, раскомментировать и заменить
      # маршрут — это единственное изменение (плюс OPENCODE_GO_API_KEY в
      # /etc/hermes-agent/env ниже):
      #   model = {
      #     provider = "opencode-go";
      #     default  = "deepseek-v4.1-flash";
      #   };
    };

    # Ключи провайдера живут в /etc/hermes-agent/env (root:root, 0600) — файл
    # создаёт наш activation-скрипт ниже, в стор и в git он не попадает.
    # Содержимое — по одной переменной вида KEY=value на строку (inline-комментарии
    # в самом файле не использовать):
    #   OPENCODE_ZEN_API_KEY   — обязателен; основной маршрут. Токен берётся из
    #                            локального ~/.local/share/opencode/auth.json
    #                            (провайдер `opencode`) или из
    #                            https://opencode.ai/console.
    #   DEEPSEEK_API_KEY       — только для платного фолбэка,
    #                            https://platform.deepseek.com/api_keys.
    #   OPENCODE_GO_API_KEY    — на будущее, если появится подписка OpenCode Go.
    #   OPENCODE_ZEN_BASE_URL  — запасной вариант, если релей /zen/v1 перестанет
    #                            отвечать: Hermes использует эту переменную как
    #                            переопределение базы (например,
    #                            https://opencode.ai/inference/openai/v1).
    # Записать ключи и применить (контейнер не пересоздаётся):
    #   sudoedit /etc/hermes-agent/env
    #   sudo systemctl restart hermes-agent
    #
    # ВАЖНО: активация ДОПИСЫВАЕТ содержимое файла к $HERMES_HOME/.env, но сам
    # .env каждый раз пересоздаётся с нуля (`install -m ... base $dest` в
    # апстримном mkEnvScript), поэтому ключ, вписанный руками прямо в .env,
    # теряется при первом же nixos-rebuild. Rebuild переживает только
    # /etc/hermes-agent/env. Отсутствующий/пустой файл активацию не ломает
    # (`if [ -r "$file" ]` → WARNING и дальше).
    environmentFiles = [ "/etc/hermes-agent/env" ];

    # GPU в контейнер не пробрасываем: llama.cpp крутится на хосте, а не здесь.
    # Если агенту понадобится локальная RTX 4080, добавить:
    #   container.extraOptions = [ "--gpus" "all" ];
  };

  # Файл с ключами создаём сами, декларативно. systemd.tmpfiles.rules для этого
  # не годятся: активация (и чтение environmentFiles) выполняется РАНЬШЕ
  # tmpfiles — апстримный модуль сам это фиксирует («activation runs before
  # tmpfiles», nix/nixosModules.nix:461), а tmpfiles переигрываются отдельно
  # через systemd-tmpfiles-resetup.service / sysinit-reactivation.target.
  # Содержимое не трогаем — только существование, владелец и режим 0600.
  system.activationScripts.hermes-agent-envfile = {
    deps = [ "etc" ];
    text = ''
      install -d -m 0755 /etc/hermes-agent
      if [ ! -e /etc/hermes-agent/env ]; then
        install -m 0600 /dev/null /etc/hermes-agent/env
      fi
      chmod 0600 /etc/hermes-agent/env
    '';
  };
  # Апстримный hermes-agent-setup читает environmentFiles, поэтому обязан идти
  # после нас (deps склеиваются: ["users" ...] ++ ["hermes-agent-envfile"]).
  system.activationScripts.hermes-agent-setup.deps = [ "hermes-agent-envfile" ];

  # Бэкстопы против бесконечного crash-loop. Апстримный модуль оставляет
  # Restart=always / RestartSec=5 (дефолты cfg.restart / cfg.restartSec), но НЕ
  # ставит RestartPreventExitStatus, хотя генератор systemd-юнита апстрима
  # (hermes_cli/gateway.py) помечает постоянные отказы конфига кодом 78
  # (EX_CONFIG: коллизия токенов, dm_policy=open без GATEWAY_ALLOW_ALL_USERS и
  # т.п.) и полагается именно на это правило, глуша ради него штатный лимит
  # systemd (StartLimitIntervalSec=0). Без правила 78 отказ конфига — вечный
  # рестарт.
  # Missing API key сам по себе gateway не роняет: без включённых платформ он
  # логирует «No messaging platforms enabled.» / «Gateway will continue running
  # for cron job execution.» и продолжает жить (gateway/run_startup.py:1437-1440),
  # так что дефолтный Restart оставляем.
  systemd.services.hermes-agent = {
    serviceConfig.RestartPreventExitStatus = 78;

    # Штатный лимит systemd (10 s / 5 попыток) при RestartSec=5 не срабатывает
    # никогда: попытка раз в 5 с навсегда. 5 попыток за 5 минут → юнит
    # паркуется и виден как failed; после интервала рестарты возобновляются
    # сами, либо вручную: sudo systemctl reset-failed hermes-agent.
    startLimitIntervalSec = 300;
    startLimitBurst = 5;
  };


  # ── OpenCode ────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    opencode-desktop
    opencode
  ];
}
