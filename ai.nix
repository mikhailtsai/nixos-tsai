{ config, pkgs, lib, vars, ... }:

let
  modelsDir = "/home/${vars.username}/Models";
  llamaPort = 8642;

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

    # ── Qwen3 14B 128K ───────────────────────────────────────────────────────
    #
    # Быстрый кандидат на роль orchestrator.
    # 128K GGUF уже содержит YaRN scaling.
    #
    # IQ4_XS около 8.1 GB — должен значительно лучше помещаться
    # в 12 GB VRAM вместе с KV cache.
    [qwen-orch-14b]
    model = ${modelsDir}/Qwen3-14B-128K-IQ4_XS.gguf
    ctx-size = 65536

    temperature = 0.2
    top-p = 0.9
    min-p = 0.05

    # ── Gemma 4 12B ──────────────────────────────────────────────────────────
    #
    # Второй кандидат на роль orchestrator.
    # Q4_K_M выбран ради полного/почти полного GPU residency
    # и запаса VRAM под 64K KV cache.
    [gemma-orch-12b]
    model = ${modelsDir}/gemma-4-12B-it-Q4_K_M.gguf
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


    # ── Devstral Small 2 24B ─────────────────────────────────────────────────
    #
    # Coding specialist.
    # Q4_K_M больше 12 GB VRAM, поэтому часть неизбежно будет offload.
    [devstral]
    model = ${modelsDir}/Devstral-Small-2-24B-Instruct-2512-Q4_K_M.gguf
    ctx-size = 65536

    temperature = 0.2
    top-p = 0.9
    min-p = 0.05


    # ── NVIDIA Nemotron Nano 12B v2 ──────────────────────────────────────────
    #
    # Меньше и быстрее тяжёлых 24/27B моделей.
    [nemotron]
    model = ${modelsDir}/Nemotron-Nano-12B-v2-Q5_K_M.gguf
    ctx-size = 65536

    temperature = 0.2
    top-p = 0.9
    min-p = 0.05
    
    # Other experimental models:

    [hydra]
    model = ${modelsDir}/MN-12B-Hydra-RP-RU.Q5_K_M.gguf
    ctx-size = 32768
    temperature = 0.8
    top-p = 0.9
    min-p = 0.05
    repeat-penalty = 1.07
    
    [runeweaver]
    model = ${modelsDir}/MN-12B-Runeweaver-RP-RU.Q6_K.gguf
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

    package = pkgs.llama-cpp.override {
      cudaSupport = true;
    };

    settings = {
      host = "127.0.0.1";
      port = llamaPort;

      "models-preset" = modelsPreset;

      # Одновременно загружена максимум одна модель.
      "models-max" = 1;
    };
  };


  # ── Доступ к ~/Models ──────────────────────────────────────────────────────
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
