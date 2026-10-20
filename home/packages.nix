{ pkgs, ... }:

let
  keybinds = pkgs.writeShellScriptBin "keybinds" ''
    C='\033[36m'    # cyan
    Y='\033[33m'    # yellow
    B='\033[1m'     # bold
    R='\033[0m'     # reset
    G='\033[90m'    # gray

    clear
    printf "\n"
    printf "''${B}''${C}  ══════════════════════════════════════════════════════════════════════''${R}\n"
    printf "''${B}''${C}                        ГОРЯЧИЕ КЛАВИШИ HYPRLAND''${R}\n"
    printf "''${B}''${C}  ══════════════════════════════════════════════════════════════════════''${R}\n"
    printf "\n"
    printf "''${B}  ПРИЛОЖЕНИЯ                                 ОКНА''${R}\n"
    printf "  ''${Y}Super + Enter''${R}          Терминал            ''${Y}Super + Q''${R}              Закрыть\n"
    printf "  ''${Y}Super + D''${R}              Rofi                ''${Y}Super + V''${R}              Плавающее\n"
    printf "  ''${Y}Super + E''${R}              Файлы               ''${Y}Super + F''${R}              Полный экран\n"
    printf "  ''${Y}Super + B''${R}              Firefox             ''${Y}Super + T''${R}              Поверх всех\n"
    printf "  ''${Y}Super + L''${R}              Блокировка          ''${Y}Super + C''${R}              Центрировать\n"
    printf "  ''${Y}Super + M''${R}              Меню выхода         ''${Y}Super + G''${R}              Группа окон\n"
    printf "\n"
    printf "''${B}  РАБОЧИЕ СТОЛЫ                              НАВИГАЦИЯ''${R}\n"
    printf "  ''${Y}Super + 1-0''${R}            Переключить         ''${Y}Super + Стрелки''${R}        Фокус\n"
    printf "  ''${Y}Super + Shift + 1-0''${R}    Переместить         ''${Y}Super + Shift + Стр''${R}    Переместить\n"
    printf "  ''${Y}Super + S''${R}              Scratchpad          ''${Y}Super + Ctrl + Стр''${R}     Размер\n"
    printf "  ''${Y}Super + [ ]''${R}            Пред./след.         ''${Y}Alt + Tab''${R}              Циклический\n"
    printf "\n"
    printf "''${B}  СКРИНШОТЫ                                  УТИЛИТЫ''${R}\n"
    printf "  ''${Y}Print''${R}                  Область*            ''${Y}Super + X''${R}              Буфер обмена\n"
    printf "  ''${Y}Shift + Print''${R}          Весь экран          ''${Y}Super + Shift + C''${R}      Пипетка\n"
    printf "  ''${Y}Super + Print''${R}          Swappy              ''${Y}Super + \\ ''${R}             Пароли\n"
    printf "  ''${Y}Super + Shift + Print''${R}  Весь экран → Swappy\n"
    printf "  ''${Y}Alt + Print''${R}            Активное окно       ''${Y}Super + W''${R}              Обои\n"
    printf "  ''${Y}Super + Space''${R}          OCR перевод         ''${Y}Super + Shift + W''${R}      Вкл/выкл фон\n"
    printf "  ''${Y}Super + Esc''${R}            Отмена выделения\n"
    printf "''${G}  * В полноэкранной игре (мышь захвачена) снимается весь монитор''${R}\n"
    printf "''${G}  Все скриншоты сохраняются в ~/Pictures/Screenshots''${R}\n"
    printf "\n"
    printf "''${B}  МЫШЬ                                       ПРОЧЕЕ''${R}\n"
    printf "  ''${Y}Super + ЛКМ''${R}            Перетащить          ''${Y}Alt + Shift''${R}            Раскладка\n"
    printf "  ''${Y}Super + ПКМ''${R}            Размер              ''${Y}Super + /''${R}              Шпаргалка\n"
    printf "  ''${Y}Super + Колесо''${R}         Раб. столы          ''${Y}Fn + клавиши''${R}           Громкость\n"
    printf "\n"
    printf "''${G}                      Нажми любую клавишу для выхода...''${R}\n"
    read -n 1 -s -r
  '';

  vpn = pkgs.writeShellScriptBin "vpn" ''
    case "$1" in
      up|connect|"")
        sudo openvpn --config ~/mikhail.tsai.ovpn
        ;;
      down|disconnect)
        sudo pkill -SIGTERM openvpn
        ;;
      status)
        if ip addr show tun0 &>/dev/null; then
          echo "VPN: Connected"
          ip addr show tun0 | grep inet
        else
          echo "VPN: Disconnected"
        fi
        ;;
      *)
        echo "Usage: vpn [up|down|status]"
        ;;
    esac
  '';

  wow-status = pkgs.writeShellScriptBin "wow-status" ''
    if systemctl is-active --quiet azerothcore-world; then
      echo '{"text":"⚔ WoW","class":"running","tooltip":"AzerothCore: запущен"}'
    else
      echo '{"text":"⚔ WoW","class":"stopped","tooltip":"AzerothCore: остановлен"}'
    fi
  '';

  wow-toggle = pkgs.writeShellScriptBin "wow-toggle" ''
    if systemctl is-active --quiet azerothcore-world; then
      sudo ${pkgs.systemd}/bin/systemctl stop azerothcore-world azerothcore-auth
      ${pkgs.libnotify}/bin/notify-send -i dialog-error "AzerothCore" "Сервер остановлен"
    else
      sudo ${pkgs.systemd}/bin/systemctl start azerothcore-world azerothcore-auth
      ${pkgs.libnotify}/bin/notify-send -i dialog-information "AzerothCore" "Сервер запущен"
    fi
  '';

  l2-status = pkgs.writeShellScriptBin "l2-status" ''
    if systemctl is-active --quiet l2hf; then
      echo '{"text":"🛡 L2","class":"running","tooltip":"L2 High Five + боты: запущен"}'
    else
      echo '{"text":"🛡 L2","class":"stopped","tooltip":"L2 High Five + боты: остановлен"}'
    fi
  '';

  l2-toggle = pkgs.writeShellScriptBin "l2-toggle" ''
    if systemctl is-active --quiet l2hf; then
      sudo ${pkgs.systemd}/bin/systemctl stop l2hf
      ${pkgs.libnotify}/bin/notify-send -i dialog-error "L2 High Five" "Сервер Lineage II остановлен"
    else
      sudo ${pkgs.systemd}/bin/systemctl start l2hf
      ${pkgs.libnotify}/bin/notify-send -i dialog-information "L2 High Five" "Сервер Lineage II запущен"
    fi
  '';

  screen-translate = pkgs.writeShellScriptBin "screen-translate" ''
    TMP_IMG=$(mktemp /tmp/screen-translate-XXXXXX.png)
    TMP_TXT=$(mktemp /tmp/screen-translate-XXXXXX)
    cleanup() { rm -f "$TMP_IMG" "''${TMP_TXT}.txt"; }
    trap cleanup EXIT

    # Полноэкранная игра (XWayland) держит мышь — slurp завис бы: снимаем весь экран.
    win="$(${pkgs.hyprland}/bin/hyprctl activewindow -j 2>/dev/null || true)"
    fullscreen=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.fullscreen // 0' 2>/dev/null || true)
    xwayland=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.xwayland // false' 2>/dev/null || true)
    if [[ "$fullscreen" != "0" && "$xwayland" == "true" ]]; then
      if ! ${pkgs.grim}/bin/grim "$TMP_IMG" 2>/dev/null; then exit 0; fi
    else
      if ! ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$TMP_IMG" 2>/dev/null; then
        exit 0
      fi
    fi

    # OCR (eng + rus чтобы не путать символы)
    ${pkgs.tesseract5.override { enableLanguages = ["eng" "rus"]; }}/bin/tesseract \
      "$TMP_IMG" "$TMP_TXT" -l eng+rus 2>/dev/null

    TEXT=$(sed 's/[[:space:]]*$//' "''${TMP_TXT}.txt" | sed '/^$/d')

    if [ -z "$TEXT" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 4000 "Переводчик" "Текст не распознан"
      exit 0
    fi

    # Перевод на русский
    TRANSLATION=$(${pkgs.translate-shell}/bin/trans -b :ru "$TEXT" 2>/dev/null)

    if [ -z "$TRANSLATION" ]; then
      ${pkgs.libnotify}/bin/notify-send -t 4000 "Переводчик" "Ошибка перевода\n$TEXT"
      exit 0
    fi

    # Скопировать в буфер и показать в плавающем окне (как шпаргалка)
    echo "$TRANSLATION" | ${pkgs.wl-clipboard}/bin/wl-copy
    RESULT_FILE=$(mktemp /tmp/translate-result-XXXXXX)
    echo "$TRANSLATION" > "$RESULT_FILE"
    ${pkgs.kitty}/bin/kitty --class cheatsheet sh -c "cat '$RESULT_FILE'; echo; echo '--- любая клавиша чтобы закрыть ---'; read -n1; rm -f '$RESULT_FILE'"
  '';

  # Print / SUPER+Print / SHIFT+Print / ALT+Print: единый хелпер для скриншотов.
  # Всегда сохраняет PNG в ~/Pictures/Screenshots и копирует его в буфер обмена.
  # Полноэкранная игра (XWayland) держит захват мыши, а stay_focused не отдаёт
  # фокус → slurp/hyprpicker не получают ни кликов, ни ESC — выделение зависает
  # намертво (приходилось закрывать сессию). Для таких окон снимаем весь монитор
  # без интерактива (grim не требует ввода).
  shot = pkgs.writeShellScriptBin "shot" ''
    set -euo pipefail

    MODE="''${1:-copy}"    # copy — сохранить + буфер | edit — ещё и swappy
    TARGET="''${2:-area}"  # area | screen | active | output

    DIR="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
    LOCK_DIR="''${XDG_RUNTIME_DIR:-''${XDG_CACHE_DIR:-$HOME/.cache}}"
    ${pkgs.coreutils}/bin/mkdir -p "$DIR"

    case "$TARGET" in
      area|screen|active|output) ;;
      *)
        ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот не сделан" "Неизвестная цель: $TARGET" || true
        exit 2
        ;;
    esac

    GAME_CLASSES='^(dota2|steam_app_.*|gamescope|wow\.exe|Wow\.exe|WowClassic\.exe|Battle\.net\.exe)$'
    FALLBACK_NOTE=""

    if [[ "$TARGET" == "area" ]]; then
      win="$(${pkgs.hyprland}/bin/hyprctl activewindow -j 2>/dev/null || true)"
      fullscreen=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.fullscreen // 0' 2>/dev/null || true)
      class=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.class // ""' 2>/dev/null || true)
      xwayland=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.xwayland // false' 2>/dev/null || true)

      if [[ "$fullscreen" != "0" && ( "$xwayland" == "true" || "$class" =~ $GAME_CLASSES ) ]]; then
        TARGET="output"
        FALLBACK_NOTE=" (весь экран: игра держит мышь)"
      fi
    fi

    # Захват — всегда в уникальный временный файл этого процесса: две съёмки
    # в одну секунду не перезаписывают и не удаляют файлы друг друга.
    tmp_capture="$(${pkgs.coreutils}/bin/mktemp -p "$DIR" .shot-XXXXXX.png 2>/dev/null || true)"
    if [[ -z "$tmp_capture" ]]; then
      ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот не сделан" "нет доступа к $DIR" || true
      exit 1
    fi

    # stderr — в файл рядом (TMPDIR может быть на nofail-моунте).
    err="$(${pkgs.coreutils}/bin/mktemp -p "$DIR" .shot-err-XXXXXX 2>/dev/null || ${pkgs.coreutils}/bin/mktemp -p /tmp 2>/dev/null || true)"
    err_target="''${err:-/dev/null}"
    tmp_out=""

    cleanup() {
      local f
      for f in "$err" "$tmp_capture" "$tmp_out"; do
        if [[ -n "$f" ]]; then ${pkgs.coreutils}/bin/rm -f "$f" 2>/dev/null || true; fi
      done
    }
    on_signal() { cleanup; trap - EXIT; exit 130; }
    trap cleanup EXIT
    trap on_signal INT TERM HUP

    capture() {
      if [[ "$TARGET" == "area" ]]; then
        ${pkgs.grimblast}/bin/grimblast --freeze save area "$tmp_capture" 2>"$err_target"
      else
        ${pkgs.grimblast}/bin/grimblast save "$TARGET" "$tmp_capture" 2>"$err_target"
      fi
    }

    rc=0
    capture || rc=$?

    # Код 2 + пустой stderr — это lock (выход до любого вывода). die() тоже
    # даёт 2, но всегда пишет "Error: ...", поэтому его не ретраим.
    if [[ "$rc" -eq 2 && -n "$err" && ! -s "$err" ]]; then
      if ! ${pkgs.procps}/bin/pgrep -f '[.]grimblast-wrapped|/bin/grimblast' >/dev/null 2>&1; then
        ${pkgs.coreutils}/bin/rm -f "$LOCK_DIR/grimblast.lock" "$LOCK_DIR/.grimblast-wrapped.lock" || true
        : > "$err" || true
        rc=0
        capture || rc=$?
      fi
    fi

    if [[ "$rc" -ne 0 ]]; then
      ${pkgs.coreutils}/bin/rm -f "$tmp_capture" || true
      detail="$(${pkgs.gnugrep}/bin/grep -m1 '^Error' "$err_target" 2>/dev/null || true)"
      if [[ -z "$detail" ]]; then
        detail="$(${pkgs.coreutils}/bin/tail -n 1 "$err_target" 2>/dev/null || true)"
      fi
      if [[ -n "$detail" ]]; then
        ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот не сделан: $detail" || true
      elif [[ "$rc" -eq 2 ]]; then
        ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот не сделан" "Уже идёт другой захват экрана" || true
      fi
      exit 0
    fi

    if [[ ! -s "$tmp_capture" ]]; then
      ${pkgs.coreutils}/bin/rm -f "$tmp_capture" || true
      ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот не сделан" "grimblast не создал файл" || true
      exit 0
    fi

    # Читаемое имя; mv -n не перезаписывает чужой файл. Если имя заняли между
    # попытками — следующий суффикс. После 20 попыток — mktemp-имя.
    stamp="$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)"
    final=""
    i=0
    while [[ "$i" -lt 20 ]]; do
      cand="$DIR/screenshot-$stamp"
      if [[ "$i" -gt 0 ]]; then cand="$cand-$i"; fi
      cand="$cand.png"
      ${pkgs.coreutils}/bin/mv -n "$tmp_capture" "$cand" 2>/dev/null || true
      if [[ ! -e "$tmp_capture" ]]; then
        final="$cand"
        break
      fi
      i=$((i + 1))
    done

    if [[ -z "$final" ]]; then
      placeholder="$(${pkgs.coreutils}/bin/mktemp -p "$DIR" "screenshot-$stamp-XXXXXX.png" 2>/dev/null || true)"
      if [[ -n "$placeholder" ]] && ${pkgs.coreutils}/bin/mv -f "$tmp_capture" "$placeholder"; then
        final="$placeholder"
      else
        if [[ -n "$placeholder" ]]; then ${pkgs.coreutils}/bin/rm -f "$placeholder" || true; fi
        ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот не сделан" "Не удалось сохранить файл в $DIR" || true
        exit 1
      fi
    fi

    # Файл — главное; буфер обмена не должен ломать уведомление.
    ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$final" || true

    # edit: swappy пишет результат в tmp_out при выходе. Заменяем файл только
    # при успешном выходе, непустом результате и PNG-сигнатуре.
    if [[ "$MODE" == "edit" ]]; then
      tmp_out="$(${pkgs.coreutils}/bin/mktemp "$DIR/.swappy-XXXXXX.png" 2>/dev/null || true)"
      if [[ -n "$tmp_out" ]]; then
        sw_rc=0
        ${pkgs.swappy}/bin/swappy -f "$final" -o "$tmp_out" || sw_rc=$?
        png_magic="$(${pkgs.coreutils}/bin/od -An -tx1 -N4 "$tmp_out" 2>/dev/null | ${pkgs.coreutils}/bin/tr -d ' \n' || true)"
        if [[ "$sw_rc" -eq 0 && -s "$tmp_out" && "$png_magic" == "89504e47" ]]; then
          if ${pkgs.coreutils}/bin/mv -f "$tmp_out" "$final"; then
            tmp_out=""
            ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$final" || true
          else
            ${pkgs.libnotify}/bin/notify-send -a shot "Скриншот" "Не удалось заменить файл; правка сохранена: $tmp_out" || true
            tmp_out=""
          fi
        else
          ${pkgs.coreutils}/bin/rm -f "$tmp_out" || true
          tmp_out=""
        fi
      fi
    fi

    ${pkgs.libnotify}/bin/notify-send -i "$final" -a shot "Скриншот" \
      "$(${pkgs.coreutils}/bin/basename "$final")''${FALLBACK_NOTE}" || true
  '';

  # Совместимость: старые бинды и шпаргалка ссылаются на shot-area.
  shot-area = pkgs.writeShellScriptBin "shot-area" ''
    exec ${shot}/bin/shot "$@"
  '';

  # SUPER+ESC: аварийная отмена зависшего выделения области (игра схватила мышь).
  shot-cancel = pkgs.writeShellScriptBin "shot-cancel" ''
    set -euo pipefail
    ${pkgs.procps}/bin/pkill -x slurp 2>/dev/null || true
    sleep 0.3
    ${pkgs.procps}/bin/pkill -x hyprpicker 2>/dev/null || true
    LOCK_DIR="''${XDG_RUNTIME_DIR:-''${XDG_CACHE_DIR:-$HOME/.cache}}"
    ${pkgs.coreutils}/bin/rm -f "$LOCK_DIR/grimblast.lock" "$LOCK_DIR/.grimblast-wrapped.lock" || true
    ${pkgs.libnotify}/bin/notify-send -t 2500 -a grimblast "Выделение области отменено" || true
  '';

  # Зашифрованное хранилище: открыть LUKS → yazi в ~/Vault → закрыть при выходе.
  # Каждый запуск требует LUKS-passphrase; выход из yazi сразу блокирует раздел.
  vault = pkgs.writeShellScriptBin "vault" ''
    MNT="$HOME/Vault"

    # Блокировка при любом выходе, включая SIGHUP (закрытие окна через super+q).
    # trap снимаем сразу, чтобы EXIT после INT/TERM/HUP не запустил lock повторно.
    lock() {
      trap - EXIT INT TERM HUP
      if sudo /run/current-system/sw/bin/vault-umount; then
        ${pkgs.libnotify}/bin/notify-send "🔒 Vault" "Хранилище заблокировано" 2>/dev/null || true
      else
        ${pkgs.libnotify}/bin/notify-send -u critical "⚠️ Vault" "Не удалось заблокировать — выполни: sudo vault-umount" 2>/dev/null || true
      fi
    }
    trap lock EXIT INT TERM HUP

    echo "🔒 Введите пароль от Vault:"
    if ! sudo /run/current-system/sw/bin/vault-mount; then
      echo "❌ Не удалось открыть Vault (неверный пароль или нет ФС внутри)."
      exit 1
    fi

    echo "🔓 Vault открыт. Закрой yazi — хранилище заблокируется."
    ${pkgs.yazi}/bin/yazi "$MNT"
  '';

  power-menu = pkgs.writeShellScriptBin "power-menu" ''
    chosen=$(printf "  Lock\n  Logout\n  Suspend\n  Reboot\n  Shutdown" | rofi -dmenu -i -p "Power" -theme-str '
      window { width: 300px; }
      listview { lines: 5; }
    ')

    case "$chosen" in
      *Lock)     hyprlock ;;
      *Logout)   hyprctl dispatch exit ;;
      *Suspend)  systemctl suspend ;;
      *Reboot)   systemctl reboot ;;
      *Shutdown) systemctl poweroff ;;
    esac
  '';
in

{
  home.packages = [
    keybinds
    vpn
    power-menu
    wow-status
    wow-toggle
    l2-status
    l2-toggle
    screen-translate
    shot
    shot-area
    shot-cancel
    vault
  ] ++ (with pkgs; [
    # Node.js
    nodejs
    yarn
    bun

    # CLI утилиты
    eza
    bat
    delta
    lazygit
    tldr
    zoxide

    # Медиа
    imv
    yt-dlp

    # Уведомления
    libnotify

    # Переводчик с экрана (OCR + translate-shell)
    (tesseract5.override { enableLanguages = ["eng" "rus"]; })
    translate-shell

    # Документация (mkdocs serve)
    (python3.withPackages (ps: with ps; [ mkdocs mkdocs-material ]))

    # Дополнительные шрифты
    nerd-fonts.symbols-only
  ]);
}
