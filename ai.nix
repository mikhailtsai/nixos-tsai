{ config, pkgs, lib, vars, ... }:

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
    # 96K контекста: модель поддерживает 262144, а веса крошечные (~6.5 GB
    # с mmproj), поэтому VRAM позволяет. KV q4_0 ≈ 30 KB/токен (гибридное
    # внимание — растёт только на full-attention слоях): 65536 ≈ 1.96 GB,
    # 98304 ≈ 2.9 GB ⇒ пик ~9.5 GB из 12 GB. Расширяет запас для агентских
    # сессий, где контекст легко доходит до 40K+.
    [bonsai]
    model = ${modelsDir}/Ternary-Bonsai-2-27B-PTQ1_0.gguf
    mmproj = ${modelsDir}/Ternary-Bonsai-2-27B-mmproj-Q8_0.gguf
    ctx-size = 98304

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


  # ── OpenCode ────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    opencode-desktop
    opencode
  ];
}
