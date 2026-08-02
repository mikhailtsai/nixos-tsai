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
    printf "  ''${Y}Print''${R}                  Область             ''${Y}Super + X''${R}              Буфер обмена\n"
    printf "  ''${Y}Shift + Print''${R}          Весь экран          ''${Y}Super + Shift + C''${R}      Пипетка\n"
    printf "  ''${Y}Super + Print''${R}          Swappy              ''${Y}Super + \\ ''${R}             Пароли\n"
    printf "  ''${Y}Alt + Print''${R}            Активное окно       ''${Y}Super + W''${R}              Обои\n"
    printf "  ''${Y}Super + Space''${R}          OCR перевод         ''${Y}Super + Shift + W''${R}      Вкл/выкл фон\n"
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

  screen-translate = pkgs.writeShellScriptBin "screen-translate" ''
    TMP_IMG=$(mktemp /tmp/screen-translate-XXXXXX.png)
    TMP_TXT=$(mktemp /tmp/screen-translate-XXXXXX)
    cleanup() { rm -f "$TMP_IMG" "''${TMP_TXT}.txt"; }
    trap cleanup EXIT

    # Выбрать область и сделать скриншот
    if ! ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$TMP_IMG" 2>/dev/null; then
      exit 0
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

  wow-toggle = pkgs.writeShellScriptBin "wow-toggle" ''
    if systemctl is-active --quiet azerothcore-world; then
      sudo ${pkgs.systemd}/bin/systemctl stop azerothcore-world azerothcore-auth
      ${pkgs.libnotify}/bin/notify-send -i dialog-error "AzerothCore" "Сервер остановлен"
    else
      sudo ${pkgs.systemd}/bin/systemctl start azerothcore-world azerothcore-auth
      ${pkgs.libnotify}/bin/notify-send -i dialog-information "AzerothCore" "Сервер запущен"
    fi
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
    screen-translate
    vault
  ] ++ (with pkgs; [
    # Node.js
    nodejs
    yarn

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
