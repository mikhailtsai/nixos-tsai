{ pkgs, vars, ... }:

# Панель локальных моделей.
#
#   • llama.cpp — NixOS-сервис (router) на 127.0.0.1:8642, сам выгружает
#     простаивающие модели (sleep-idle-seconds + timer в ai.nix);
#   • ComfyUI   — локальная генерация изображений на 127.0.0.1:8188.
#
# Скрипты ниже дают статус для waybar (ЛКМ — подробности, ПКМ — меню выгрузки) и
# кнопки ручного освобождения памяти, когда что-то застряло. Адреса берутся из
# vars.ai, чтобы не расходиться с system-модулем (ai.nix).

let
  inherit (vars.ai) llamaPort comfyPort;

  # Общая библиотека: адреса и хелперы (VRAM/ОЗУ, состояние движков).
  aiLib = pkgs.writeText "ai-lib.sh" ''
    LLAMA_PORT=${toString llamaPort}
    COMFY_PORT=${toString comfyPort}

    _JQ=${pkgs.jq}/bin/jq
    _CURL=${pkgs.curl}/bin/curl

    # "used total" в МиБ для первой GPU
    vram_mib() {
      nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null \
        | head -n1 | awk -F', *' '{print $1" "$2}'
    }

    # "used total" в МиБ (used = total - available)
    ram_mib() {
      awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%d %d", (t-a)/1024, t/1024}' /proc/meminfo
    }

    fmt_gib() { awk -v m="$1" 'BEGIN{printf "%.1f", m/1024}'; }

    # id моделей llama.cpp, реально занимающих память (loaded) или уснувших (sleeping)
    llama_all_loaded_ids() {
      $_CURL -sf --max-time 3 "http://127.0.0.1:$LLAMA_PORT/v1/models" 2>/dev/null \
        | $_JQ -r '.data[]? | select(.status.value == "loaded" or .status.value == "sleeping") | .id' 2>/dev/null
    }

    llama_loaded_id() { llama_all_loaded_ids | head -n1; }
  '';

  # ── Выгрузка из памяти ────────────────────────────────────────────────────

  llmUnload = pkgs.writeShellScriptBin "llama-unload" ''
    set -u
    . ${aiLib}
    found=0
    for m in $(llama_all_loaded_ids); do
      found=1
      if $_CURL -sf --max-time 60 -H 'Content-Type: application/json' \
           -d "{\"model\":\"$m\"}" "http://127.0.0.1:$LLAMA_PORT/models/unload" >/dev/null; then
        echo "llama.cpp: $m выгружена"
      else
        echo "llama.cpp: не удалось выгрузить $m"
      fi
    done
    [ "$found" = 0 ] && echo "llama.cpp: загруженных моделей нет"
  '';

  comfyFree = pkgs.writeShellScriptBin "comfy-free" ''
    set -u
    . ${aiLib}
    if $_CURL -sf --max-time 20 -X POST "http://127.0.0.1:$COMFY_PORT/free" \
         -H 'Content-Type: application/json' \
         -d '{"unload_models":true,"free_memory":true}' >/dev/null 2>&1; then
      echo "ComfyUI: модели выгружены, память освобождена"
    else
      echo "ComfyUI недоступен (не запущен)"
    fi
  '';

  aiFree = pkgs.writeShellScriptBin "ai-free" ''
    set -u
    . ${aiLib}
    ${llmUnload}/bin/llama-unload
    ${comfyFree}/bin/comfy-free
    echo "---"
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
  '';

  # ── Статус для waybar ─────────────────────────────────────────────────────

  aiStatus = pkgs.writeShellScriptBin "ai-status" ''
    set -u
    . ${aiLib}

    vram=$(vram_mib); vu=''${vram%% *}; vt=''${vram##* }
    ram=$(ram_mib);  ru=''${ram%% *};  rt=''${ram##* }
    vpct=0; [ "''${vt:-0}" -gt 0 ] && vpct=$(( vu * 100 / vt ))
    rpct=0; [ "''${rt:-0}" -gt 0 ] && rpct=$(( ru * 100 / rt ))
    vg=$(fmt_gib "$vu"); vtg=$(fmt_gib "$vt")
    rg=$(fmt_gib "$ru"); rtg=$(fmt_gib "$rt")

    lid=$(llama_loaded_id)

    if [ -n "$lid" ]; then
      text="🧠 $lid $vpct%"; class="running"
    else
      text="○ GPU $vpct%"; class="stopped"
    fi

    lstr="нет"; [ -n "$lid" ] && lstr="$lid"

    tooltip=$(printf 'VRAM  %s / %s GiB  (%s%%)\nОЗУ   %s / %s GiB  (%s%%)\n\nllama.cpp:  %s\n\nЛКМ — подробнее · ПКМ — меню' \
      "$vg" "$vtg" "$vpct" "$rg" "$rtg" "$rpct" "$lstr")

    $_JQ -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
      '{text:$text, tooltip:$tooltip, class:$class}'
  '';

  # ── Подробный отчёт и живой монитор ───────────────────────────────────────

  aiReport = pkgs.writeShellScriptBin "ai-report" ''
    set -u
    . ${aiLib}

    B=$(printf '\033[1m'); C=$(printf '\033[36m'); G=$(printf '\033[90m'); R=$(printf '\033[0m')

    vram=$(vram_mib); vu=''${vram%% *}; vt=''${vram##* }
    ram=$(ram_mib);  ru=''${ram%% *};  rt=''${ram##* }
    vpct=0; [ "''${vt:-0}" -gt 0 ] && vpct=$(( vu * 100 / vt ))
    rpct=0; [ "''${rt:-0}" -gt 0 ] && rpct=$(( ru * 100 / rt ))
    vg=$(fmt_gib "$vu"); vtg=$(fmt_gib "$vt")
    rg=$(fmt_gib "$ru"); rtg=$(fmt_gib "$rt")

    printf '\n  %s%s🚀 ЛОКАЛЬНЫЕ МОДЕЛИ%s  %s%s%s\n\n' "$B" "$C" "$R" "$G" "$(date '+%H:%M:%S')" "$R"

    gpu_line=$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,power.draw --format=csv,noheader,nounits 2>/dev/null | head -n1)
    if [ -n "$gpu_line" ]; then
      IFS='|' read -r gname gtemp gutil gpow <<< "$(printf '%s' "$gpu_line" | awk -F', ' '{print $1"|"$2"|"$3"|"$4}')"
      printf '  %sGPU%s  %s\n' "$B" "$R" "$gname"
      printf '    VRAM  %s / %s GiB  (%s%%)   %s°C   загрузка %s%%   %s W\n' "$vg" "$vtg" "$vpct" "$gtemp" "$gutil" "$gpow"
      printf '    %sВ VRAM:%s\n' "$G" "$R"
      nvidia-smi --query-compute-apps=used_memory,pid,process_name --format=csv,noheader,nounits 2>/dev/null \
        | sort -rn | head -n8 \
        | while IFS=',' read -r mem pid pname; do
            mem=$(printf '%s' "$mem" | tr -d ' ')
            pid=$(printf '%s' "$pid" | tr -d ' ')
            printf '      %6s MiB  %s  (pid %s)\n' "$mem" "$(basename "$pname")" "$pid"
          done
    fi
    printf '\n  %sОЗУ%s   %s / %s GiB  (%s%%)\n' "$B" "$R" "$rg" "$rtg" "$rpct"

    # ── llama.cpp ────────────────────────────────────────────────────────────
    printf '\n  %sllama.cpp%s  http://127.0.0.1:%s\n' "$B" "$R" "$LLAMA_PORT"
    models=$($_CURL -sf --max-time 3 "http://127.0.0.1:$LLAMA_PORT/v1/models" 2>/dev/null)
    if [ -n "$models" ]; then
      printf '%s' "$models" | $_JQ -r '
        .data[]? |
        ( if .status.value == "loaded" then
            "    ● \(.id)   ctx \(.meta.n_ctx // "?")   \(.meta.ftype // "?")   \(((.meta.size // 0) / 1073741824 * 10 | round) / 10) GiB"
          elif .status.value == "sleeping" then
            "    ◐ \(.id)   (уснула: процесс без модели в памяти)"
          else
            "    ○ \(.id)"
          end )'
      lid=$(llama_loaded_id)
      if [ -n "$lid" ]; then
        met=$($_CURL -sf --max-time 2 "http://127.0.0.1:$LLAMA_PORT/metrics?model=$lid" 2>/dev/null)
        if printf '%s' "$met" | ${pkgs.gnugrep}/bin/grep -q '^llamacpp:tokens_predicted_total'; then
          printf '%s' "$met" | awk -F' ' '
            /^llamacpp:tokens_predicted_total/{t=$2}
            /^llamacpp:tokens_predicted_seconds_total/{ts=$2}
            /^llamacpp:prompt_tokens_total/{p=$2}
            /^llamacpp:prompt_seconds_total/{ps=$2}
            END{ printf "    скорость:";
              if (ts>0) printf " %.1f tok/s", t/ts;
              if (ps>0) printf "   prefill: %.0f tok/s", p/ps;
              printf "\n" }'
        fi
      fi
    else
      printf '    %s(сервер недоступен)%s\n' "$G" "$R"
    fi

    # ── ComfyUI ──────────────────────────────────────────────────────────────
    if $_CURL -sf --max-time 2 "http://127.0.0.1:$COMFY_PORT/system_stats" >/dev/null 2>&1; then
      printf '\n  %sComfyUI%s  доступен (http://127.0.0.1:%s)\n' "$B" "$R" "$COMFY_PORT"
    else
      printf '\n  %sComfyUI%s  не запущен\n' "$B" "$R"
    fi
    printf '\n'
  '';

  aiMonitor = pkgs.writeShellScriptBin "ai-monitor" ''
    set -u
    while true; do
      clear
      ${aiReport}/bin/ai-report
      printf '\n  %sобновление каждую секунду · Ctrl-C — выход%s' \
        "$(printf '\033[90m')" "$(printf '\033[0m')"
      sleep 1
    done
  '';

  aiDetails = pkgs.writeShellScriptBin "ai-details" ''
    exec ${pkgs.kitty}/bin/kitty --class ai-monitor --title "Локальные модели" ${aiMonitor}/bin/ai-monitor
  '';

  # ── Меню по правому клику ─────────────────────────────────────────────────

  aiMenu = pkgs.writeShellScriptBin "ai-menu" ''
    set -u
    chosen=$(printf '%s\n' \
      '🧠  Выгрузить llama.cpp' \
      '🖼  Освободить ComfyUI' \
      '🧹  Освободить всю VRAM' \
      '📊  Процессы VRAM (nvidia-smi)' \
      '🔎  Подробный монитор' \
      | ${pkgs.rofi}/bin/rofi -dmenu -i -p 'Локальные модели' -theme-str 'window { width: 460px; }')

    [ -z "$chosen" ] && exit 0

    case "$chosen" in
      *'Выгрузить llama.cpp'*) out=$(${llmUnload}/bin/llama-unload 2>&1) ;;
      *'Освободить ComfyUI'*)  out=$(${comfyFree}/bin/comfy-free 2>&1) ;;
      *'всю VRAM'*)            out=$(${aiFree}/bin/ai-free 2>&1) ;;
      *'nvidia-smi'*)          exec ${pkgs.kitty}/bin/kitty --class nvidia-smi --title "nvidia-smi" sh -c 'nvidia-smi; printf "\n\nлюбая клавиша…"; read -n1' ;;
      *'Подробный монитор'*)   exec ${aiDetails}/bin/ai-details ;;
      *) exit 0 ;;
    esac

    ${pkgs.libnotify}/bin/notify-send -i dialog-information 'Локальные модели' "$out"
  '';
in
{
  home.packages = [
    aiStatus
    aiReport
    aiMonitor
    aiDetails
    aiMenu
    llmUnload
    comfyFree
    aiFree
  ];
}
