{ config, lib, pkgs, ... }:

# ── Read-only host diagnostics для Hermes Agent ─────────────────────────────
#
# Hermes живёт в контейнере и не должен иметь доступа на запись к хосту.
# Раз в 10 минут oneshot-сервис от root складывает в /var/lib/hermes-hostdiag/<stamp>/
# текстовый снимок состояния хоста: журнал, диск, память, docker, GPU.
#
# Каталог снимков намеренно ВНЕ /var/lib/hermes: тот смонтирован в контейнер
# rw как /data, поэтому его содержимое контролирует агент. /var/lib/hermes-hostdiag
# принадлежит root:hermes (0750) и смонтирован в контейнер ТОЛЬКО read-only как
# /hostdiag. Агент не может ни создавать там файлы, ни подменять их симлинками,
# поэтому root-сервис не получает primitive «запись/ chmod через ссылку».
#
# Никаких sudo-правил, capabilities и privileged mode: пишет только сервис от
# root, агенту достаётся чтение (файлы 0640, каталоги 0750, группа hermes).
#
# Живой журнал хоста отдельно проброшен в контейнер ro как /host-journal
# (см. container.extraVolumes в ai.nix).
let
  hermesGroup = config.services.hermes-agent.group;
  # Литерал, а не ${hermesStateDir}/...: базовый каталог обязан быть вне
  # agent-writable bind-mount'а /var/lib/hermes → /data.
  baseDir = "/var/lib/hermes-hostdiag";

  # Скрипт собирается в сторе; runtimeInputs фиксируют PATH, чтобы юнит не
  # зависел от профиля системы. nvidia-smi намеренно не входит в замыкание:
  # его приносит проприетарный драйвер из /run/current-system/sw/bin.
  hostdiag = pkgs.writeShellApplication {
    name = "hermes-hostdiag";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.procps
      pkgs.systemd
      pkgs.util-linux
      config.virtualisation.docker.package
      config.nix.package
    ];
    text = ''
      set -euo pipefail
      # Группа hermes у новых файлов появляется не из chown, а из Group= юнита.
      # umask 0027 даёт файлам 0640; каталоги создаём явным mkdir -m 0750.
      umask 0027

      # Снимки — простой текст: отключаем цвета, пейджер и подсказки CLI.
      export SYSTEMD_COLORS=0
      export NO_COLOR=1
      export TERM=dumb
      export DOCKER_CLI_HINTS=false
      # Драйверный nvidia-smi лежит только в системном профиле.
      export PATH="$PATH:/run/current-system/sw/bin"

      # BASE/OUT можно переопределить для сухого прогона без root.
      BASE="''${HERMES_HOSTDIAG_BASE:-${baseDir}}"
      OUT="''${OUT:-$BASE/$(date +%Y%m%d-%H%M%S)}"

      # Базовый каталог в реальном юните создаёт tmpfiles (root:hermes 0750).
      # Скрипт его не пересоздаёт и НЕ меняет режим: иначе 0750 можно случайно
      # «починить» до 0755. Для сухого прогона без root разрешаем создать базу
      # самим — но только если она отсутствует и мы не root.
      if [ -L "$BASE" ]; then
        echo "hermes-hostdiag: $BASE — симлинк, отказываемся работать" >&2
        exit 1
      fi
      if [ ! -d "$BASE" ]; then
        if [ "$(id -u)" -eq 0 ]; then
          echo "hermes-hostdiag: $BASE отсутствует (tmpfiles не отработал)" >&2
          exit 1
        fi
        # Сухой прогон без root: путь может быть вложенным, поэтому -p.
        mkdir -p "$BASE"
        chmod 0750 "$BASE"
      fi
      # В реальном юните база обязана быть 0:<gid hermes> 750: иначе контейнер
      # мог бы подложить туда свои каталоги/ссылки, а 0755 открыл бы снимки
      # (журнал, docker ps) всем пользователям хоста. В сухом прогоне проверка
      # не имеет смысла (каталог принадлежит запускающему пользователю).
      if [ "$(id -u)" -eq 0 ]; then
        _hermes_gid="$(id -g ${hermesGroup} 2>/dev/null || true)"
        _base_meta="$(stat -c '%u:%g %a' "$BASE" 2>/dev/null || true)"
        if [ "$_base_meta" != "0:''${_hermes_gid} 750" ]; then
          echo "hermes-hostdiag: $BASE должен быть 0:''${_hermes_gid} 750, а сейчас ''${_base_meta:-?} — отказываемся работать" >&2
          exit 1
        fi
      fi

      # mkdir без -p: если каталог с текущим timestamp уже есть (например, его
      # успел создать кто-то другой), запуск падает, а не переиспользует его.
      if ! mkdir -m 0750 "$OUT"; then
        echo "hermes-hostdiag: каталог снимка $OUT уже существует или недоступен" >&2
        exit 1
      fi

      section() {
        echo
        echo "===== $1 ====="
      }

      # README — генерируемый артефакт: он обязан соответствовать модулю, поэтому
      # пишем его при каждом запуске. Сначала во временный файл (umask 0027 → 0640),
      # затем cmp: идентичный текст не трогаем, изменённый заменяем атомарно через
      # mv -f (inode новый, режим 0640, группа hermes — из Group=/UMask= юнита).
      cat > "$BASE/README.md.tmp" <<'EOF'
      # Host diagnostics для Hermes

      Файл сгенерирован юнитом `hermes-hostdiag`; ручные правки перезаписываются.

      Этот каталог — read-only снимок состояния хоста, который готовит хостовый
      таймер `hermes-hostdiag.timer` (root, systemd). На хосте он лежит в
      `/var/lib/hermes-hostdiag`, в контейнере `hermes-agent` смонтирован
      read-only как `/hostdiag`.

      Снимки обновляются каждые 10 минут. В каждом подкаталоге
      `<YYYYmmdd-HHMMSS>/` лежат:

      * `journal.txt` — warning/error текущего boot, хвост предыдущего boot,
        grep по OOM/GPF/lockup, список boot'ов;
      * `system.txt` — ядро, uptime, loadavg, failed units, текущая генерация NixOS;
      * `disk.txt` — `df`, `df -i`, размеры store/journal/state, disk-usage журнала;
      * `memory.txt` — meminfo, PSI, swap, top-25 процессов по RSS;
      * `docker.txt` — список контейнеров, `docker stats`, лимиты памяти;
      * `gpu.txt` — `nvidia-smi` (если GPU и драйвер есть).

      Доступ у агента ТОЛЬКО на чтение: каталог смонтирован read-only, каталоги
      снимков — 0750, файлы — 0640, владелец root, группа `hermes`. Записать
      сюда или подменить файл симлинком из контейнера нельзя.
      Старое удаляется автоматически: хранятся 100 последних снимков и ничего
      старше 2 суток.

      ## Ежедневная инвентаризация диска

      Отдельный юнит `hermes-disk-inventory` запускается каждый день в 03:30
      (и через 15 минут после загрузки, если запуск был пропущен). Он пишет
      подробный отчёт в `inventory/<YYYYmmdd-HHMMSS>/inventory.txt`: `df`,
      `du` по крупным каталогам, `docker system df -v`, образы и остановленные
      контейнеры, мёртвые пути store, корни GC, генерации системы, файлы
      больше 1 ГБ.

      В контейнере это доступно как `/hostdiag/inventory/latest/inventory.txt`
      (`latest` — относительный симлинк на последний каталог). Если корень
      заполнен на 85% и больше, рядом появляется `inventory/latest/ALERT`
      со строкой `disk usage N%`, а в журнал хоста уходит warning от
      `hermes-disk-inventory`.

      Ретенция инвентаризаций: ничего старше 30 дней, максимум 14 копий.

      ## Живой журнал

      Полный журнал хоста смонтирован в контейнер read-only как `/host-journal`
      (`/var/log/journal` на хосте). В образе контейнера нет ни `journalctl`,
      ни `systemctl`, поэтому используется хостовый бинарник из ro-монтирования
      `/nix/store`. Брать нужно НЕ `minimal`-сборку: она собрана без zstd и не
      читает zstd-сжатые файлы журнала хоста. Файлы журнала —
      `0640 root:systemd-journal`, поэтому из контейнера (uid 986) их читает
      только `sudo -n` (он там passwordless); `docker exec -u root` работает
      без sudo.

      Путь к бинарнику:

          JS=$(ls -d /nix/store/*-systemd-[0-9]*/bin/journalctl 2>/dev/null | grep -v minimal | head -1)

      Основной пример:

          sudo -n "$JS" -D /host-journal -b --no-pager -n 200

      Важно: `-D` и `--file` взаимоисключающие, вместе их передавать нельзя.

      Другие примеры:

          sudo -n "$JS" -D /host-journal -b -p warning --no-pager -n 500
          sudo -n "$JS" -D /host-journal -b -1 --no-pager -n 300
          sudo -n "$JS" -D /host-journal --list-boots

      Монтирование read-only: писать в журнал из контейнера нельзя.
      EOF

      # Симлинк на месте README разрываем до сравнения: cmp не должен читать
      # чужой файл, а mv -f заменил бы не ссылку, а её цель. База root-owned,
      # это defence in depth.
      if [ -L "$BASE/README.md" ]; then
        rm -f -- "$BASE/README.md"
      fi
      if cmp -s "$BASE/README.md.tmp" "$BASE/README.md"; then
        rm -f -- "$BASE/README.md.tmp"
      else
        mv -f -- "$BASE/README.md.tmp" "$BASE/README.md"
      fi

      # ── journal.txt ─────────────────────────────────────────────────────────
      {
        section "Текущий boot: warning и выше (последние 500)"
        journalctl -b -p warning --no-pager -n 500 -o short-iso 2>&1 || true

        section "Предыдущий boot: хвост (последние 300)"
        journalctl -b -1 --no-pager -n 300 -o short-iso 2>&1 || true

        section "OOM / GPF / lockup: текущий boot"
        journalctl -b --no-pager -o short-iso 2>&1 \
          | grep -Ei 'out of memory|oom-kill|oom_reaper|general protection|segfault|soft lockup|hard lockup|watchdog' \
          || true

        section "OOM / GPF / lockup: предыдущий boot"
        journalctl -b -1 --no-pager -o short-iso 2>&1 \
          | grep -Ei 'out of memory|oom-kill|oom_reaper|general protection|segfault|soft lockup|hard lockup|watchdog' \
          || true

        section "Список boot'ов"
        journalctl --list-boots --no-pager 2>&1 || true
      } > "$OUT/journal.txt" 2>&1

      # ── system.txt ──────────────────────────────────────────────────────────
      {
        section "uname -a"
        uname -a

        section "uptime"
        # Секции не должны ронять весь запуск до ретенции — деградируем мягко.
        uptime 2>&1 || echo "недоступно"

        section "loadavg"
        cat /proc/loadavg 2>/dev/null || echo "недоступно"

        section "systemctl --failed"
        systemctl --failed --no-pager 2>&1 || true

        section "Текущая система (readlink -f /run/current-system)"
        readlink -f /run/current-system

        section "Последние 5 генераций профиля system"
        # nix-env открывает <profile>.lock на запись даже для --list-generations,
        # а /nix под ProtectSystem=strict только для чтения. Листаем копию
        # симлинков профиля в приватном /tmp: сам /nix остаётся read-only.
        prof_tmp="$(mktemp -d)"
        cp -a /nix/var/nix/profiles/system /nix/var/nix/profiles/system-*-link "$prof_tmp"/ 2>/dev/null || true
        nix-env --list-generations -p "$prof_tmp/system" 2>&1 | tail -n 5 || true
        rm -rf -- "$prof_tmp" || true

        section "systemctl is-system-running"
        systemctl is-system-running 2>&1 || true
      } > "$OUT/system.txt" 2>&1

      # ── disk.txt ────────────────────────────────────────────────────────────
      {
        section "df -h"
        # Один залипший mount не должен обрывать запуск до ретенции.
        df -h 2>&1 || true

        section "df -i"
        df -i 2>&1 || true

        section "du -sh /nix/store /var/log/journal /var/lib/hermes"
        du -sh /nix/store /var/log/journal /var/lib/hermes 2>&1 || true

        section "journalctl --disk-usage"
        journalctl --disk-usage 2>&1 || true
      } > "$OUT/disk.txt" 2>&1

      # Порог 85%: пишем ALERT в снимок и строку в журнал хоста.
      disk_pct="$(df --output=pcent / | tail -n1 | tr -dc '0-9' || true)"
      if [ -n "$disk_pct" ] && [ "$disk_pct" -ge 85 ]; then
        printf 'disk usage %s%%\n' "$disk_pct" > "$OUT/ALERT"
        logger -p user.warning -t hermes-hostdiag "disk usage ''${disk_pct}%" || true
      fi

      # ── memory.txt ──────────────────────────────────────────────────────────
      {
        section "/proc/meminfo"
        cat /proc/meminfo 2>/dev/null || echo "недоступно"

        for f in cpu io memory; do
          section "/proc/pressure/$f"
          cat "/proc/pressure/$f" 2>/dev/null || echo "недоступно"
        done

        section "swapon --show"
        swapon --show 2>&1 || true

        section "top-25 процессов по RSS"
        ps -eo pid,comm,%mem,rss --sort=-rss 2>&1 | head -n 26 || true
      } > "$OUT/memory.txt" 2>&1

      # ── docker.txt ──────────────────────────────────────────────────────────
      {
        section "docker ps"
        docker ps --no-trunc 2>&1 || true

        section "docker stats --no-stream (timeout 20s)"
        timeout 20 docker stats --no-stream 2>&1 || true

        section "Лимиты памяти контейнеров (HostConfig.Memory, байты)"
        ids="$(docker ps -q 2>/dev/null || true)"
        if [ -n "$ids" ]; then
          echo "$ids" | xargs -r docker inspect \
            -f '{{.Name}} Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}}' \
            2>&1 || true
        else
          echo "нет запущенных контейнеров или docker недоступен"
        fi
      } > "$OUT/docker.txt" 2>&1

      # ── gpu.txt ─────────────────────────────────────────────────────────────
      {
        section "nvidia-smi"
        if command -v nvidia-smi >/dev/null 2>&1; then
          nvidia-smi --query-gpu=name,driver_version,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv 2>&1 || true
        else
          echo "nvidia-smi недоступен (нет GPU или драйвера)"
        fi
      } > "$OUT/gpu.txt" 2>&1

      # ── Ретенция ────────────────────────────────────────────────────────────
      # Работаем только внутри root-owned базы, только с реальными каталогами
      # (-type d не матчит симлинки, -P запрещает переход по ссылкам).
      # Сначала всё старше 48 часов (find -mmin, а не -mtime: +2 = >3 суток),
      # затем лишнее сверх 100 самых новых. Имена каталогов — сортируемые
      # timestamp'ы, поэтому sort -r достаточен. Удаляем только через
      # find ... -exec rm -rf -- {} +, чтобы путь не собирался вручную.
      find -P "$BASE" -mindepth 1 -maxdepth 1 -type d -name '20*-*' -mmin +2880 \
        -exec rm -rf -- {} + 2>/dev/null || true

      # find может вернуть non-zero (например, каталог исчез во время обхода),
      # а ретенция — не повод валить весь запуск, поэтому весь конвейер
      # прикрыт `|| true`. LC_ALL=C фиксирует порядок сортировки timestamp-имён.
      export LC_ALL=C
      find -P "$BASE" -mindepth 1 -maxdepth 1 -type d -name '20*-*' -printf '%f\n' 2>/dev/null \
        | sort -r \
        | tail -n +101 \
        | while IFS= read -r old; do
            find -P "$BASE" -mindepth 1 -maxdepth 1 -type d -name "$old" \
              -exec rm -rf -- {} + 2>/dev/null || true
          done || true
    '';
  };

  # Раз в сутки — подробная инвентаризация диска: что именно занимает место,
  # какие образы/контейнеры/генерации можно удалить. Пишет в
  # ${baseDir}/inventory/<stamp>/ (root:hermes 0750), отдаёт в контейнер
  # read-only через уже существующий /hostdiag.
  diskInventory = pkgs.writeShellApplication {
    name = "hermes-disk-inventory";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.procps
      pkgs.systemd
      pkgs.util-linux
      config.virtualisation.docker.package
      config.nix.package
    ];
    text = ''
      set -euo pipefail
      # Группу hermes новым каталогам/файлам даёт Group= юнита, режимы — umask
      # 0027 и явные mkdir -m 0750 (каталоги 0750, файлы 0640).
      umask 0027

      export SYSTEMD_COLORS=0
      export NO_COLOR=1
      export TERM=dumb
      export DOCKER_CLI_HINTS=false
      # Фиксированная локаль: вывод утилит и порядок сортировки не зависят от
      # окружения, а не-ASCII имена не ломают sort.
      export LC_ALL=C

      # BASE можно переопределить для сухого прогона без root. Родитель
      # (/var/lib/hermes-hostdiag) и сам inventory создаются tmpfiles от root.
      BASE="''${HERMES_DISK_INVENTORY_BASE:-${baseDir}/inventory}"

      if [ -L "$BASE" ]; then
        echo "hermes-disk-inventory: $BASE — симлинк, отказываемся работать" >&2
        exit 1
      fi
      if [ ! -d "$BASE" ]; then
        if [ "$(id -u)" -eq 0 ]; then
          echo "hermes-disk-inventory: $BASE отсутствует (tmpfiles не отработал)" >&2
          exit 1
        fi
        # Сухой прогон без root: путь может быть вложенным, поэтому -p.
        mkdir -p "$BASE"
        chmod 0750 "$BASE"
      fi
      # В реальном юните база обязана быть 0:<gid hermes> 750: иначе контейнер
      # мог бы подложить туда свои каталоги/ссылки, а 0755 открыл бы инвентарь
      # (пути, docker-образы) всем пользователям хоста. В сухом прогоне проверка
      # не имеет смысла (каталог принадлежит запускающему пользователю).
      if [ "$(id -u)" -eq 0 ]; then
        _hermes_gid="$(id -g ${hermesGroup} 2>/dev/null || true)"
        _base_meta="$(stat -c '%u:%g %a' "$BASE" 2>/dev/null || true)"
        if [ "$_base_meta" != "0:''${_hermes_gid} 750" ]; then
          echo "hermes-disk-inventory: $BASE должен быть 0:''${_hermes_gid} 750, а сейчас ''${_base_meta:-?} — отказываемся работать" >&2
          exit 1
        fi
      fi

      # mkdir без -p: каталог с текущим timestamp обязан быть новым. Если он
      # уже есть (кто-то успел создать), запуск падает, а не переиспользует его.
      OUT="$BASE/$(date +%Y%m%d-%H%M%S)"
      if ! mkdir -m 0750 "$OUT"; then
        echo "hermes-disk-inventory: каталог $OUT уже существует или недоступен" >&2
        exit 1
      fi

      section() {
        echo
        echo "===== $1 ====="
      }

      # Каждая секция терпит сбой своей команды (|| true): один сломанный
      # docker/залипший mount не должен обрывать весь отчёт.
      {
        section "df -h"
        df -h 2>&1 || true

        section "df -i"
        df -i 2>&1 || true

        section "du -xhd1 / (топ-40)"
        # tr -c '[:print:]\t\n' '?': имена файлов может создать агент (в /data,
        # /home), и ANSI-escape или перевод строки в имени подделали бы отчёт.
        du -xhd1 / 2>/dev/null | tr -c '[:print:]\t\n' '?' | sort -rh | head -40 || true

        section "du -xhd1 /home /var /nix (топ-60)"
        du -xhd1 /home /var /nix 2>/dev/null | tr -c '[:print:]\t\n' '?' | sort -rh | head -60 || true

        section "du -sh: store, journal, hermes"
        du -sh /nix/store /var/log/journal /var/lib/hermes 2>/dev/null \
          | tr -c '[:print:]\t\n' '?' || true

        # -x: /var/lib/docker — своя ФС (overlay), без -x верхний уровень
        # посчитал бы слои контейнеров дважды.
        section "du -shx: docker"
        du -shx /var/lib/docker 2>/dev/null | tr -c '[:print:]\t\n' '?' || true

        section "du -shx: Storage/Vault/Models/ollama"
        du -shx /home/leet/Storage /home/leet/Vault /home/leet/Models /var/lib/ollama 2>/dev/null \
          | tr -c '[:print:]\t\n' '?' || true

        section "docker system df -v (timeout 120s)"
        timeout 120 docker system df -v 2>&1 || true

        section "docker image ls (топ-100)"
        docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}} {{.CreatedSince}} {{.ID}}' 2>&1 | head -100 || true

        section "docker ps -a: только exited"
        docker ps -a --filter status=exited --format '{{.Names}} {{.Image}} {{.Status}}' 2>&1 || true

        # nix-store открывает /nix/var/nix/gc.lock на запись даже для --print-*,
        # а /nix под ProtectSystem=strict только для чтения. Поэтому честно
        # различаем «ноль путей» и «команда недоступна»: пустой вывод от
        # подавленной ошибки выглядел бы как здоровый GC-кандидат 0.
        section "nix-store --gc --print-dead: количество путей"
        dead_out="$(mktemp)"
        if nix-store --gc --print-dead > "$dead_out" 2>/dev/null; then
          wc -l < "$dead_out"
        else
          echo "unavailable (read-only /nix; run on host)"
        fi
        rm -f -- "$dead_out"

        section "nix-store --gc --print-roots (топ-100)"
        roots_out="$(mktemp)"
        if nix-store --gc --print-roots > "$roots_out" 2>/dev/null; then
          head -100 "$roots_out"
        else
          echo "unavailable (read-only /nix; run on host)"
        fi
        rm -f -- "$roots_out"

        section "Генерации профиля system (последние 10)"
        # nix-env открывает <profile>.lock на запись даже для --list-generations,
        # а /nix под ProtectSystem=strict только для чтения. Листаем копию
        # симлинков профиля в приватном /tmp: сам /nix остаётся read-only.
        prof_tmp="$(mktemp -d)"
        cp -a /nix/var/nix/profiles/system /nix/var/nix/profiles/system-*-link "$prof_tmp"/ 2>/dev/null || true
        nix-env --list-generations -p "$prof_tmp/system" 2>&1 | tail -10 || true
        rm -rf -- "$prof_tmp" || true

        section "journalctl --disk-usage"
        journalctl --disk-usage 2>&1 || true

        section "swapon --show"
        swapon --show 2>&1 || true

        section "free -h"
        free -h 2>&1 || true

        section "Файлы больше 1G (топ-40)"
        find / -xdev -type f -size +1G -printf '%s %p\n' 2>/dev/null \
          | tr -c '[:print:]\t\n' '?' | sort -rn | head -40 || true

        # Отдельно смонтированные тяжёлые каталоги: в контейнер они не видны
        # (там только /hostdiag и /host-journal), а место занимают именно они.
        # Vault может быть не размонтирован/LUKS закрыт — || true терпит это.
        section "Файлы >1G в Storage/Vault/Models/ollama"
        find /home/leet/Storage /home/leet/Vault /home/leet/Models /var/lib/ollama \
          -xdev -type f -size +1G -printf '%s %p\n' 2>/dev/null \
          | tr -c '[:print:]\t\n' '?' | sort -rn | head -40 || true
      } > "$OUT/inventory.txt" 2>&1

      # Порог 85%: отдельный файл-маркер, чтобы агент не парсил df.
      disk_pct="$(df --output=pcent / | tail -n1 | tr -dc '0-9' || true)"
      if [ -n "$disk_pct" ] && [ "$disk_pct" -ge 85 ]; then
        printf 'disk usage %s%%\n' "$disk_pct" > "$OUT/ALERT"
        logger -p user.warning -t hermes-disk-inventory "disk usage ''${disk_pct}%" || true
      fi

      # latest — ОТНОСИТЕЛЬНЫЙ симлинк: внутри контейнера /hostdiag смонтирован
      # read-only, и абсолютный путь /var/lib/hermes-hostdiag/... там не резолвится.
      ln -sfn "$(basename "$OUT")" "$BASE/latest"

      # ── Ретенция ────────────────────────────────────────────────────────────
      # Сначала всё старше 30 суток, затем лишнее сверх 14 самых новых. Имена
      # каталогов — сортируемые timestamp'ы, LC_ALL=C фиксирует порядок.
      # Только реальные каталоги (-type d не матчит симлинки, -P не ходит по ним).
      find -P "$BASE" -mindepth 1 -maxdepth 1 -type d -name '20*-*' -mtime +30 \
        -exec rm -rf -- {} + 2>/dev/null || true

      export LC_ALL=C
      find -P "$BASE" -mindepth 1 -maxdepth 1 -type d -name '20*-*' -printf '%f\n' 2>/dev/null \
        | sort -r \
        | tail -n +15 \
        | while IFS= read -r old; do
            find -P "$BASE" -mindepth 1 -maxdepth 1 -type d -name "$old" \
              -exec rm -rf -- {} + 2>/dev/null || true
          done || true
    '';
  };
in
{
  # Модуль имеет смысл только вместе с агентом: без него не нужны ни снимки,
  # ни таймер, ни каталог. Иначе юнит остался бы активным сам по себе.
  config = lib.mkIf config.services.hermes-agent.enable {
    # База создаётся tmpfiles от root. 0750 root:hermes: контейнер (gid 981)
    # читает, но не пишет; сам путь не пересекается с /var/lib/hermes.
    systemd.tmpfiles.rules = [
      "d ${baseDir} 0750 root ${hermesGroup} -"
      "d ${baseDir}/inventory 0750 root ${hermesGroup} -"
    ];

    systemd.services.hermes-hostdiag = {
      description = "Read-only host diagnostics snapshot for Hermes Agent";
      # После docker.service: первый снимок не должен гоняться с медленным
      # стартом Docker (сбой docker-секции и так терпится, это лишь качество).
      after = [ "docker.service" ];
      # Запускается таймером, отдельный wantedBy сервису не нужен.
      serviceConfig = {
        Type = "oneshot";
        # User=root остаётся осознанно: сервису нужны journal хоста и сокет
        # docker, а доступ к docker-сокету и так эквивалентен root. Запуск от
        # hermes не дал бы безопасности, но сломал бы чтение root-only данных.
        # Изоляцию даёт набор Protect*/CapabilityBoundingSet ниже.
        User = "root";
        # Group=hermes вместо chown: новые каталоги/файлы сразу получают
        # группу hermes (0640/0750), без каких-либо chown -R.
        Group = hermesGroup;
        ExecStart = "${hostdiag}/bin/hermes-hostdiag";
        UMask = "0027";

        # ProtectSystem=strict делает /var read-only, поэтому запись разрешена
        # точечно в root-owned базу снимков. Сокет docker и файлы журнала при
        # этом остаются доступны: strict запрещает запись, а не чтение/connect.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ baseDir ];

        # Дальнейшая изоляция root-юнита.
        #
        # PrivatePIDs / ProtectProc=invisible / ProcSubset=pid СОЗНАТЕЛЬНО не
        # включаем. В приватном PID-namespace недоступны /proc/meminfo,
        # /proc/loadavg и /proc/pressure/*, а ps -e видит только процессы
        # самого юнита — то есть memory.txt и список top-процессов пустеют,
        # и смысл снимка теряется. Хостовый /proc обязан оставаться видимым.
        # Primitive «запись через подложенный путь» закрыт иначе: база снимков
        # вынесена в root-owned /var/lib/hermes-hostdiag (0750 root:hermes),
        # смонтированный в контейнер только read-only, поэтому скрывать PID
        # namespace ради этого не требуется.
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        # ProtectHostname НЕ включаем: он даёт приватный UTS-namespace, и
        # `uname -a` в system.txt показал бы имя юнита, а не хоста.
        RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];

        # Только реально нужные capabilities: читать журнал и /proc (DAC_*),
        # читать /proc чужих процессов для ps (SYS_PTRACE), читать
        # journal/kmsg (SYSLOG). CHOWN/FOWNER/SETGID/SETUID не нужны: chown и
        # chmod в скрипте больше нет, а группу hermes выставляет Group=.
        # PrivateDevices НЕ включаем: nvidia-smi нужен /dev/nvidia*.
        # SystemCallFilter НЕ включаем: проверить docker/journalctl/nvidia-smi
        # под фильтром на этой машине нельзя, риск сломать снимки выше выгоды.
        CapabilityBoundingSet = [
          "CAP_DAC_READ_SEARCH"
          "CAP_DAC_OVERRIDE"
          "CAP_SYS_PTRACE"
          "CAP_SYSLOG"
        ];
      };
      # ProtectHome скрывает /root; docker CLI и nix-env не должны ходить в HOME.
      environment.HOME = "/tmp";
    };

    systemd.timers.hermes-hostdiag = {
      description = "Periodic read-only host diagnostics snapshot for Hermes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = "10min";
        # Persistent не имеет эффекта с OnUnitActiveSec (нет OnCalendar).
        Unit = "hermes-hostdiag.service";
      };
    };

    # Ежедневная инвентаризация диска. Изоляция повторяет hermes-hostdiag,
    # но ProtectHome=true здесь НЕЛЬЗЯ: он скрыл бы /home/leet, а инвентарь
    # обязан его читать. Поэтому read-only: /home виден, но не изменяем;
    # /root дополнительно закрыт InaccessiblePaths.
    systemd.services.hermes-disk-inventory = {
      description = "Daily disk inventory for Hermes Agent";
      after = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = hermesGroup;
        ExecStart = "${diskInventory}/bin/hermes-disk-inventory";
        UMask = "0027";
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        InaccessiblePaths = [ "/root" ];
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ baseDir ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectKernelLogs = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" ];
        # Инвентарю не нужны ни /proc чужих процессов (SYS_PTRACE), ни чтение
        # kmsg (SYSLOG) — только обход ФС под DAC. Меньше прав у root-юнита.
        CapabilityBoundingSet = [
          "CAP_DAC_READ_SEARCH"
          "CAP_DAC_OVERRIDE"
        ];
        # Полный обход / и docker system df -v на большом store — долго.
        TimeoutStartSec = "1h";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
      # Защита от попадания в /root: HOME нужен docker CLI и nix-env.
      environment.HOME = "/tmp";
    };

    systemd.timers.hermes-disk-inventory = {
      description = "Daily disk inventory for Hermes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15min";
        OnCalendar = "*-*-* 03:30:00";
        Persistent = true;
        RandomizedDelaySec = "30min";
        Unit = "hermes-disk-inventory.service";
      };
    };
  };
}
