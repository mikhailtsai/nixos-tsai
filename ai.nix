{ config, pkgs, lib, vars, hermes-agent, ... }:

let
  modelsDir = "/home/${vars.username}/Storage/Models";
  inherit (vars.ai) llamaPort;

  # Каталог состояния hermes-agent (services.hermes-agent.stateDir); внутри —
  # .hermes (то же самое, что $HERMES_HOME). Используется в активации ниже.
  stateDir = config.services.hermes-agent.stateDir;

  # Возврат объявленного апстримом режима на $HERMES_HOME. Одна и та же команда
  # нужна в двух местах: в активации (baseline при switch/boot) и в сервисе
  # таймера ниже (периодический re-assert, потому что апстримный
  # secure_parent_dir() перебивает режим в рантайме). Держим текст в let, чтобы
  # не дублировать литералы; владелец/группа/путь берутся из опций модуля.
  #
  # Скрипт намеренно идемпотентный, «тихий» и БЕЗ exit: если режим уже верный —
  # не делаем ничего; если каталога ещё нет (активация не отработала) — это
  # успешный no-op. Ни одна ветка не может вернуть non-zero (stat/chown/chmod
  # прикрыты `|| true`), поэтому сервис не «залипает» в failed и не валит
  # nixos-rebuild switch. `exit` тут был бы ещё и опасен: в активации этот же
  # текст выполняется в общем контексте сниппета, и exit оборвал бы активацию.
  #
  # Порядок «сначала chown, потом chmod» важен: chown сбрасывает setgid.
  # Пишем ТОЛЬКО метаданные самого каталога: ни auth.json, ни другие файлы
  # внутри не открываются и не меняются, поэтому триггерить самих себя нечем.
  hermesHome = "${stateDir}/.hermes";

  # CLI внутри контейнера: /data/current-package — симлинк на актуальный пакет,
  # его обновляет активация. В PATH образа (ubuntu:24.04) его нет, поэтому
  # docker exec требует полный путь.
  hermesPkgBin = "/data/current-package/bin/hermes";

  # Ожидание готовности контейнера перед стартом панели (см. hermes-dashboard).
  #
  # hermes-agent.service — Type=simple, а его ExecStart — `docker start -a`:
  # systemd считает юнит запущенным сразу после fork/exec, хотя entrypoint
  # внутри контейнера в этот момент ещё работает root'ом и на первом старте
  # создаёт пользователя hermes (useradd). Поэтому after/requires на
  # hermes-agent.service НЕ гарантируют, что контейнер уже можно использовать:
  # при пересоздании контейнера панель падала с «container ... is not running»
  # (ExecStartPre --stop), а на первом буте — «unable to find user hermes: no
  # matching entries in passwd file» (ExecStart).
  #
  # Ждём ОБА условия: (1) docker inspect отдаёт State.Running=true и (2)
  # `docker exec -u hermes` уже работает, то есть uid/имя hermes резолвится в
  # /etc/passwd контейнера. Ограничение по времени обязательно: иначе
  # «контейнер не поднялся» превратилось бы в вечное ожидание на старте.
  #
  # Скрипт лежит отдельным файлом в store, а не inline в `bash -c`: внутри есть
  # кавычки, а экранирование аргументов в ExecStartPre/systemd с ними хрупкое.
  # bash и docker подставляются абсолютными путями — юнит не зависит от PATH
  # (sleep — тоже, иначе остаётся ровно та же зависимость).
  hermesDashboardWait = pkgs.writeText "hermes-dashboard-wait.sh" ''
    set -u

    docker=${config.virtualisation.docker.package}/bin/docker
    sleep_cmd=${pkgs.coreutils}/bin/sleep
    container=hermes-agent
    timeout=120
    step=2
    waited=0

    while :; do
      if [ "$("$docker" inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" = true ] \
        && "$docker" exec -u hermes "$container" sh -lc true >/dev/null 2>&1; then
        exit 0
      fi

      if [ "$waited" -ge "$timeout" ]; then
        echo "hermes-dashboard: контейнер $container не готов за $timeout с:" >&2
        echo "  нужен State.Running=true и рабочий 'docker exec -u hermes' (пользователь hermes ещё не создан?)" >&2
        exit 1
      fi

      "$sleep_cmd" "$step"
      waited=$((waited + step))
    done
  '';

  # Пакет Hermes (вариант messaging). Один инстанс на всё: сервис, CLI,
  # Electron-десктоп (его passthru hermesDesktop) — чтобы venv был один.
  hermesPkg = (hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.messaging).override {
    # Апстрим не передаёт version в callPackage (дефолт "0.0.0"), и install-stamp
    # получает baseVersion=0.0.0. Из-за этого `hermes --version` врёт, а
    # `hermes plugins install` отказывает всем плагинам с requires_hermes
    # («running 0.0.0»). Ставим реальный тег пина; на venv это не влияет —
    # version участвует только в install-stamp.json и в имени деривации.
    version = "0.22.2";

    # Electron — из СИСТЕМНОГО nixpkgs, а не из nixpkgs flake-инпута: только так
    # glibc Electron совпадает с glibc драйверов в /run/opengl-driver, иначе
    # MESA-LOADER не находит GLIBC_2.43 и libgallium не грузится (из-за этого
    # GPU и был выключен). electron_42-bin — готовый upstream-бинарь (dontBuild,
    # zip), с passthru.headers для сборки node-pty. 41.x — EOL, поэтому 42.
    # Пересобирается только hermesDesktop (renderer + node-pty + обёртка).
    electron = pkgs.electron_42-bin;
  };

  hermesStatePermsCmd = ''
    # $HERMES_HOME: владелец hermes:hermes, режим 2770 (group traverse + setgid).
    _hermes_perm_want="${config.services.hermes-agent.user}:${config.services.hermes-agent.group}"
    _hermes_perm_fix() {
      # Симлинк не трогаем: контейнер может заменить каталог ссылкой, а
      # chmod/chown без -h пошли бы по ней к чужому файлу на хосте.
      [ -d "$1" ] && [ ! -L "$1" ] || return 0
      [ "$(stat -c '%a' "$1" 2>/dev/null || true)" = "$2" ] \
        || chmod --no-dereference "$2" "$1" || true
    }
    if [ -d ${hermesHome} ] && [ ! -L ${hermesHome} ]; then
      _hermes_perm_have="$(stat -c '%a %U:%G' ${hermesHome} 2>/dev/null || true)"
      if [ "$_hermes_perm_have" != "2770 $_hermes_perm_want" ]; then
        chown -h "$_hermes_perm_want" ${hermesHome} || true
        chmod --no-dereference 2770 ${hermesHome} || true
      fi
      # backups/ — хостовый CLI (при addToSystemPackages config.yaml = 0660, то
      # есть запись для группы hermes) кладёт сюда копию config.yaml перед
      # записью. Без g+w каждый старт печатает «Could not back up …
      # Permission denied». Содержимое — копии того же config.yaml, поэтому
      # 2770 доступ не расширяет.
      _hermes_perm_fix ${hermesHome}/backups 2770
      _hermes_perm_fix ${hermesHome}/backups/config 2770
      # installs/*/.install.lock — pm открывает замок через os.open(..., 0o600)
      # и требует записи. Файл создаёт процесс в контейнере (hermes), поэтому
      # хостовый CLI в группе hermes падает с «install state is not writable by
      # this user». Это flock-замок без данных: g+w расширяет доступ ровно на
      # группу hermes (и новых замков это тоже касается — отсюда find).
      # find -P и -type f: симлинки (в т.ч. подложенные контейнером) не
      # матчатся, поэтому chmod не пойдёт по ссылке.
      if [ -d ${hermesHome}/installs ] && [ ! -L ${hermesHome}/installs ]; then
        find -P ${hermesHome}/installs -maxdepth 2 -type f -name .install.lock ! -perm 0660 \
          -exec chmod --no-dereference 0660 {} + 2>/dev/null || true
      fi
      # Сами файлы бэкапов хостовый CLI перезаписывает по имени
      # (config.yaml.good.<время>), а созданы они 0600 — группе нужен w.
      if [ -d ${hermesHome}/backups/config ] && [ ! -L ${hermesHome}/backups/config ]; then
        find -P ${hermesHome}/backups/config -maxdepth 1 -type f ! -perm 0660 \
          -exec chmod --no-dereference 0660 {} + 2>/dev/null || true
      fi
    fi
  '';

  # ── Маршрутизация моделей Hermes: единый источник правды ────────────────────
  #
  # Основной маршрут — подписка Claude через плагин
  # claude-subscription-directsdk-experimental: sonnet-5-5 везде, opus-5-5
  # только в профиле superpower-engineer. Второй эшелон — платный релей
  # OpenCode Go (дешёвая flash → сильные модели), последний — платный DeepSeek.
  # Значения используются и в settings (root/default), и в активации
  # именованных профилей ниже, чтобы правки в одном месте не разъезжались.
  hermesMain = {
    provider = "claude-subscription-directsdk-experimental";
    default = "claude-sonnet-5-5";
  };

  # Штатный per-turn failover root/default, bastion и tsai-tech-devops.
  # Порядок = приоритет: сначала добираем подписку Go другими моделями, и
  # только потом платный DeepSeek.
  hermesMainFallbacks = [
    { provider = "opencode-go"; model = "deepseek-v4.1-flash"; }
    { provider = "openai-codex"; model = "gpt-6-luna"; }
    { provider = "opencode-go"; model = "mimo-v2.6-pro"; }
    { provider = "opencode-go"; model = "qwen3.8-max"; }
    { provider = "opencode-go"; model = "beam-free"; }
    { provider = "opencode-go"; model = "glm-5.3-flash"; }
    { provider = "opencode-go"; model = "minimax-m3"; }
    { provider = "opencode-go"; model = "kimi-k2.7-code"; }
    { provider = "deepseek"; model = "deepseek-flash"; }
  ];

  # superpower-engineer: собственный порядок (sol/kimi/glm первыми), без
  # 10-звенной цепочки основного профиля.
  hermesSuperpowerFallbacks = [
    { provider = "openai-codex"; model = "gpt-6.1-sol"; }
    { provider = "opencode-go"; model = "kimi-k3"; }
    { provider = "opencode-go"; model = "hy4-preview"; }
    { provider = "opencode-go"; model = "glm-5.3"; }
    { provider = "opencode-go"; model = "deepseek-v4.1-flash"; }
    { provider = "deepseek"; model = "deepseek-flash"; }
  ];

  # Вспомогательные задачи (auxiliary). Одинаковы во всех четырёх конфигах.
  #
  # Переключены на CommandCode GOAT ТОЛЬКО вспомогательные задачи: основной
  # маршрут (`model`/`fallback_providers` — подписка Claude и Go-релей) не
  # тронут. GOAT даёт 8x лимит на deepseek-v4.1-flash и glm-5.3-flash и 2x на
  # mimo-v2.6-pro, поэтому aux уходит туда, а не в платный DeepSeek.
  #
  # commandcode — встроенный провайдер Hermes 0.22.2 (chat_completions,
  # https://api.commandcode.ai/provider/v1, ключ COMMANDCODE_API_KEY), id
  # моделей содержат слэш. Для claude-* нужен отдельный встроенный провайдер
  # commandcode-anthropic (anthropic_messages, /messages): claude-* в реестре
  # CommandCode отдаются только по /messages, и chat_completions для них не
  # годится. Поэтому approval закреплён на commandcode-anthropic.
  #
  # Блок providers.commandcode здесь НЕ заводим: base_url/key_env уже есть во
  # встроенном реестре, а частичная кастомная запись была бы отброшена
  # нормализатором.
  #
  # free_only в апстриме (agent/auxiliary_client.py) гейтит только
  # OpenRouter-лейн; явно закреплённые здесь провайдеры (commandcode,
  # commandcode-anthropic, deepseek, openai-codex) всё равно используются и
  # тарифицируются. review и kanban_decomposer идут по отдельной цепочке
  # (mimo primary, codex sol первым фолбэком) — см. ниже.
  #
  # Ключ: COMMANDCODE_API_KEY=<…> в /etc/hermes-agent/env (root:root, 0600),
  # затем `sudo systemctl restart hermes-agent` — env читается только при
  # старте. Пока ключа нет, commandcode-слоты падают по цепочке на
  # deepseek/deepseek-flash с предупреждением в логе.
  #
  # Pre-flight перед перезапуском: GET /provider/v1/models и один
  # chat/completions. Ключ GOAT-тарифа может отвечать 403 upgrade_required —
  # это значит, что аккаунту не выдан GOAT, и aux останется на DeepSeek.
  hermesAuxiliaryChain = [
    { provider = "commandcode"; model = "z-ai/glm-5.3-flash"; }
    { provider = "deepseek"; model = "deepseek-flash"; }
  ];
  # review/kanban_decomposer: claude-sonnet-5-5 на GOAT (anthropic wire, 1x).
  # Допуск 1x: $10 = 70 кредитов, то есть ~0.7 кредита (~$0.10) за review.
  # Задачи редкие, поэтому расход почти нулевой и он выкупает простаивающие
  # кредиты пула, давая при этом лучшее качество. sol остаётся ПЕРВЫМ
  # фолбэком — снова подхватится сам, когда подписка восстановится; дальше
  # идут дешёвые MiMo и DeepSeek.
  hermesAuxiliaryReviewChain = [
    { provider = "openai-codex"; model = "gpt-6.1-sol"; }
    { provider = "commandcode"; model = "xiaomi/mimo-v2.6-pro"; }
    { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; }
    { provider = "deepseek"; model = "deepseek-flash"; }
  ];
  hermesAuxiliary = {
    free_only = true;

    # approval — claude-haiku-5-5 живёт только на /messages, поэтому
    # commandcode-anthropic, а не commandcode. Цепочка своя: quality-модели
    # CommandCode, затем платный DeepSeek.
    approval = {
      provider = "commandcode-anthropic";
      model = "claude-haiku-5-5";
      fallback_chain = [
        { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; }
        { provider = "deepseek"; model = "deepseek-flash"; }
      ];
    };

    # Массовые задачи: 8x-модель CommandCode, затем DeepSeek.
    title_generation = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    compression = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    mcp = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    memory_query_rewrite = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    tts_audio_tags = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    voice_chat = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    skills_hub = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    triage_specifier = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    profile_describer = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    curator = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    goal_judge = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    monitor = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    background_review = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; enabled = true; fallback_chain = hermesAuxiliaryChain; };
    moa_reference = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };
    moa_aggregator = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };

    # vision: deepseek-v4.1-flash у CommandCode поддерживает изображения.
    vision = { provider = "commandcode"; model = "deepseek/deepseek-v4.1-flash"; fallback_chain = hermesAuxiliaryChain; };

    # Качество важнее объёма: primary — claude-sonnet-5-5 на GOAT (anthropic
    # wire, 1x, ~$0.10 за review при почти нулевом объёме). sol — первый
    # фолбэк на случай восстановления подписки; дальше дешёвые MiMo и DeepSeek.
    review = { provider = "commandcode-anthropic"; model = "claude-sonnet-5-5"; fallback_chain = hermesAuxiliaryReviewChain; };
    kanban_decomposer = { provider = "commandcode-anthropic"; model = "claude-sonnet-5-5"; fallback_chain = hermesAuxiliaryReviewChain; };
  };

  # ── Пин маршрутизации именованных профилей ─────────────────────────────────
  #
  # У модуля нет опции для профилей: они живут в
  # $HERMES_HOME/profiles/<name>/config.yaml и активацией апстрима не
  # затрагиваются. Без этого пина nixos-rebuild откатывал бы свежие правки из
  # дашборда. `default` — это корневой config.yaml, его deep-merge'ит сам
  # модуль (services.hermes-agent.settings).
  #
  # Скрипт использует тот же ruamel.yaml, что и апстримный merge, и сливает
  # ТОЛЬКО перечисленные ключи: model.provider/default, fallback_providers,
  # auxiliary. Остальное (aliases, mcp_servers, gateway, moa, security, …)
  # остаётся рантайм-состоянием. Запись — только при реальном изменении
  # распарсенного объекта, поэтому совпадающие файлы (и их комментарии) не
  # трогаются. Ошибка одного профиля логируется и не валит активацию.
  hermesProfileRouting = pkgs.writeScript "hermes-profile-routing" ''
    #!${pkgs.python3.withPackages (ps: [ ps.ruamel-yaml ])}/bin/python3
    import grp
    import json
    import os
    import pwd
    import stat
    import sys
    import tempfile
    from pathlib import Path

    from ruamel.yaml import YAML

    yaml = YAML(typ="safe", pure=True)
    # Конфиги используют YAML 1.1 (yes/off и т.п.) — как в апстримном merge.
    yaml.version = (1, 1)
    yaml.default_flow_style = False
    yaml.sort_base_mapping_type_on_output = False


    def warn(message):
        print(f"hermes-profile-routing: {message}", file=sys.stderr)


    def deep_merge(base, override):
        result = dict(base)
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = deep_merge(result[key], value)
            else:
                result[key] = value
        return result


    def resolve_owner(path):
        # Нужен только при запуске от root; при euid != 0 chown не делается.
        try:
            return pwd.getpwnam("hermes").pw_uid, grp.getgrnam("hermes").gr_gid
        except (KeyError, OSError):
            st = os.lstat(path)
            return st.st_uid, st.st_gid


    def checked_path(home, name):
        # Дерево profiles принадлежит контейнерному пользователю, поэтому
        # контейнер мог подменить любой компонент симлинком. Проверяем каждый
        # компонент через lstat и никогда не идём по ссылке.
        for component in (home, home / "profiles", home / "profiles" / name):
            try:
                st = os.lstat(component)
            except FileNotFoundError:
                return None
            if not stat.S_ISDIR(st.st_mode):
                warn(f"{component}: not a real directory (symlink?) — skipped")
                return None
        path = home / "profiles" / name / "config.yaml"
        try:
            st = os.lstat(path)
        except FileNotFoundError:
            return None
        if not stat.S_ISREG(st.st_mode):
            warn(f"{path}: not a regular file (symlink?) — skipped")
            return None
        return path


    def merge_profile(name, payload, home):
        path = checked_path(home, name)
        if path is None:
            return
        # O_NOFOLLOW закрывает и гонку между lstat и открытием файла.
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, encoding="utf-8") as handle:
            existing = yaml.load(handle) or {}
        if not isinstance(existing, dict):
            raise ValueError("top-level YAML value is not a mapping")
        merged = deep_merge(existing, payload)
        if merged == existing:
            return
        fd, tmp = tempfile.mkstemp(prefix=".config.yaml.", dir=str(path.parent))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                yaml.dump(merged, handle)
            if os.geteuid() == 0:
                os.chown(tmp, *resolve_owner(path))
            os.chmod(tmp, 0o660)
            os.replace(tmp, path)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise


    def main():
        home = Path(sys.argv[1])
        with open(sys.argv[2], encoding="utf-8") as handle:
            payloads = json.load(handle)
        for name, payload in payloads.items():
            try:
                merge_profile(name, payload, home)
            except Exception as exc:  # один битый профиль не валит активацию
                warn(f"{name}: {exc}")
        return 0


    sys.exit(main())
  '';

  # payload для профилей: bastion и tsai-tech-devops — как root/default,
  # superpower-engineer — opus и своя цепочка фолбэков. aliases не пиним:
  # у superpower-engineer свой набор (opus/sol).
  hermesProfileRoutingPayload = pkgs.writeText "hermes-profile-routing.json" (builtins.toJSON {
    bastion = {
      model = hermesMain;
      fallback_providers = hermesMainFallbacks;
      auxiliary = hermesAuxiliary;
    };
    tsai-tech-devops = {
      model = hermesMain;
      fallback_providers = hermesMainFallbacks;
      auxiliary = hermesAuxiliary;
    };
    superpower-engineer = {
      model = hermesMain // { default = "claude-opus-5-5"; };
      fallback_providers = hermesSuperpowerFallbacks;
      auxiliary = hermesAuxiliary;
    };
  });

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

  # ── Иконка Hermes для меню приложений ──────────────────────────────────────
  #
  # Берём мастер-иконку из исходников flake (она уже в /nix/store) и кладём её
  # в hicolor, чтобы пункт меню находил её по имени "hermes".
  hermesIcon = pkgs.runCommand "hermes-icon" { } ''
    mkdir -p $out/share/icons/hicolor/scalable/apps
    cp ${hermes-agent}/assets/icon-master.svg $out/share/icons/hicolor/scalable/apps/hermes.svg
  '';

  # ── Hermes Desktop (Electron) ───────────────────────────────────────────────
  # Официальное приложение из flake: hermesDesktop — passthru нашего пакета,
  # поэтому venv тот же (.messaging), без второй копии Python.
  #
  # Архитектура: десктоп — ЧИСТЫЙ КЛИЕНТ всегда запущенной панели
  # (systemd.services.hermes-dashboard, 127.0.0.1:9119). Свой бэкенд он не
  # поднимает: HERMES_DESKTOP_REMOTE_URL/_TOKEN переводят резолвер в
  # remote-режим, а URL без токена резолвер отвергает исключением
  # (apps/desktop/electron/desktop-remote-route.ts), поэтому локальный `hermes`
  # не стартует и не душит те же сессии/память.
  # Внутренняя обёртка апстрима всё равно пиннит HERMES_DESKTOP_HERMES
  # (nix/desktop.nix): переменная не пустая, но она лишь выбирает бинарь для
  # локального режима, а не включает его — режим задаёт remote-URL.
  # Общая панель = общие сессии, память и cron.
  #
  # Токен лежит в рантайм-файле /etc/hermes-agent/desktop-token.env (его
  # создаёт активация hermes-agent-envfile): секрет в Nix store класть нельзя.
  # Тот же файл получает бэкенд через environmentFiles, поэтому токены
  # приложения и сервера совпадают. Без токена приложение НЕ запускаем: иначе
  # Electron молча ушёл бы в режим «поднять свой бэкенд».
  hermesDesktopBin = pkgs.writeShellApplication {
    name = "hermes-desktop";
    runtimeInputs = [ pkgs.coreutils pkgs.gnused ];
    text = ''
      export HERMES_HOME=${hermesHome}
      export HERMES_MANAGED=true

      token_file=/etc/hermes-agent/desktop-token.env
      if [ ! -r "$token_file" ]; then
        echo "hermes-desktop: не удалось прочитать $token_file" >&2
        echo "  токен панели создаёт активация NixOS: нужны членство в группе hermes (id -nG) и выполненный nixos-rebuild switch" >&2
        exit 1
      fi
      # Первая строка вида HERMES_DASHBOARD_SESSION_TOKEN=<hex>; берём
      # последнее совпадение (файл может быть дополнен) и срезаем CR/LF.
      # Пустое значение = повреждённый файл, а не повод поднимать
      # локальный бэкенд.
      token="$(sed -n 's/^HERMES_DASHBOARD_SESSION_TOKEN=//p' "$token_file" | tail -n 1 | tr -d '\r\n' || true)"
      if [ -z "$token" ]; then
        echo "hermes-desktop: в $token_file нет HERMES_DASHBOARD_SESSION_TOKEN" >&2
        echo "  токен панели создаёт активация NixOS: нужны членство в группе hermes (id -nG) и выполненный nixos-rebuild switch" >&2
        exit 1
      fi

      export HERMES_DESKTOP_REMOTE_URL=http://127.0.0.1:9119
      export HERMES_DESKTOP_REMOTE_TOKEN="$token"
      # GPU включён: Electron теперь из системного nixpkgs, его glibc совпадает
      # с /run/opengl-driver, поэтому Mesa (libgallium) грузится штатно.
      # Рендер пинуем на Intel iGPU: рендер на дискретной NVIDIA валил
      # композитор (буфер NVIDIA импортировался в Intel Mesa → i915 execbuf
      # ENOMEM → SIGABRT). Откат — вернуть этой переменной значение 1.
      export HERMES_DESKTOP_DISABLE_GPU=0
      # Сессионные переменные Hyprland тянут весь GL/VA-API на NVIDIA. Снимаем
      # их, иначе приложение уедет на dGPU (renderD128) мимо выбранного ниже
      # render-node и снова получим кросс-GPU импорт буферов и падение Hyprland.
      unset GBM_BACKEND NVD_BACKEND __GLX_VENDOR_LIBRARY_NAME LIBVA_DRIVER_NAME
      # renderD129 — Intel i915 (та же GPU, что у композитора); renderD128 —
      # NVIDIA. Именно пин render-node держит приложение на Intel iGPU, а не
      # флаги песочницы.
      # --no-zygote убран: Chromium отказывается работать без зиготы только
      # вместе с --no-sandbox («Zygote cannot be disabled if sandbox is
      # enabled»), а отключать sandbox рендерера мы не хотим — приложение
      # падало с кодом 1 сразу после старта.
      exec ${hermesPkg.hermesDesktop}/bin/hermes-desktop \
        --render-node-override=/dev/dri/renderD129 "$@"
    '';
  };

  hermesDesktopItem = pkgs.makeDesktopItem {
    name = "hermes-desktop";
    desktopName = "Hermes Desktop";
    genericName = "AI Agent";
    comment = "Hermes Agent native desktop app (Electron)";
    exec = "${hermesDesktopBin}/bin/hermes-desktop";
    icon = "hermes";
    categories = [ "Development" "Network" ];
    terminal = false;
    startupNotify = false;
  };

  # ── Ежедневный бэкап базы знаний Hermes Agent ──────────────────────────────
  #
  # Что: skills/ целиком (включая .hub, .bundled_manifest и локальные скиллы),
  # memories/, SOUL.md, profile.yaml, config.yaml; консистентные снимки
  # state.db и profiles/*/state.db (sqlite3 .backup через read-only URI, без
  # копирования -wal/-shm); для каждого профиля — profiles/*/{skills,memories,
  # SOUL.md}. Не попадают: *.lock, cache/, sandboxes/, sessions/, logs/,
  # .env, .env.*, auth.json*, .claude.
  # Куда: /home/leet/Storage/Backups/hermes/hermes-knowledge-YYYYmmdd-HHMMSS.tar.gz
  # (UTC, режим 0600, владелец leet:users; сам каталог — 0750).
  # Сколько: хранятся 10 самых свежих архивов; retention всегда оставляет
  # минимум 1 архив (значения HERMES_BACKUP_KEEP < 1 отвергаются).
  # Восстановление:
  #   systemctl stop hermes-agent.service
  #   rm -f /var/lib/hermes/.hermes/state.db-wal /var/lib/hermes/.hermes/state.db-shm
  #   rm -f /var/lib/hermes/.hermes/profiles/*/state.db-wal /var/lib/hermes/.hermes/profiles/*/state.db-shm
  #   tar -xzf <архив> -C /var/lib/hermes/.hermes
  #   chown -R hermes:hermes /var/lib/hermes/.hermes
  #   chmod 2770 /var/lib/hermes/.hermes
  #   systemctl start hermes-agent.service
  # Удалять -wal/-shm обязательно: иначе SQLite проиграет старый WAL поверх
  # восстановленной базы, что даёт повреждение/потерю данных.
  #
  # Скрипт пишет во временный *.tmp и делает mv; staging лежит на той же ФС,
  # что и dst ($dst/.staging.*), и удаляется trap'ом вместе с частичным
  # архивом. Нет $HERMES_HOME — лог и код 0; меньше 2 GiB свободного места или
  # меньше размера payload + 512 MiB — ошибка и код 1 до создания архива.
  # Повторный запуск блокируется flock'ом на $dst/.lock.
  # HERMES_SRC/HERMES_BACKUP_DST/HERMES_BACKUP_KEEP позволяют прогнать скрипт
  # без root на тестовом дереве.
  hermesKnowledgeBackup = pkgs.writeShellApplication {
    name = "hermes-knowledge-backup";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gnutar
      gzip
      sqlite
      util-linux
    ];
    text = ''
      umask 077

      src="''${HERMES_SRC:-${hermesHome}}"
      src="''${src%/}"
      dst="''${HERMES_BACKUP_DST:-/home/${vars.username}/Storage/Backups/hermes}"
      keep="''${HERMES_BACKUP_KEEP:-10}"
      backup_user="${vars.username}"
      min_free_kib=2097152
      reserve_kib=524288

      log() { printf '%s\n' "hermes-knowledge-backup: $*" >&2; }

      tmp=""
      workdir=""
      cleanup() {
        if [ -n "$workdir" ]; then
          rm -rf -- "$workdir"
        fi
        if [ -n "$tmp" ]; then
          rm -f -- "$tmp"
        fi
      }
      trap cleanup EXIT INT TERM

      if [ ! -d "$src" ]; then
        log "source $src is missing, nothing to back up"
        exit 0
      fi

      case "$keep" in
        ""|*[!0-9]*)
          log "ERROR: HERMES_BACKUP_KEEP must be an integer >= 1, got '$keep'"
          exit 1
          ;;
      esac
      if [ "$keep" -lt 1 ]; then
        log "ERROR: HERMES_BACKUP_KEEP must be >= 1 (retention always keeps at least one archive), got '$keep'"
        exit 1
      fi

      # Симлинк на месте каталога бэкапов = запись в неожиданное место.
      if [ -L "$dst" ]; then
        log "ERROR: backup destination $dst is a symlink, refusing to write through it"
        exit 1
      fi

      if [ "$(id -u)" -eq 0 ]; then
        install -d -o "$backup_user" -g users -m 0750 "$dst"
      else
        mkdir -p "$dst"
      fi

      # Один бэкап за раз на один dst (ручной запуск не пересечётся с таймером).
      exec 9>"$dst/.lock"
      flock -n 9 || { log "another run is in progress"; exit 1; }

      # Хвосты прерванных запусков старше часа.
      find "$dst" -maxdepth 1 -type f -name 'hermes-knowledge-*.tar.gz.tmp' -mmin +60 -delete

      # Базовая проверка: даже пустой архив + запас не должны упереться в диск.
      avail_kib="$(df --output=avail -k "$dst" | tail -n 1 | tr -d '[:space:]')"
      case "$avail_kib" in
        ""|*[!0-9]*)
          log "ERROR: cannot determine free space on $dst"
          exit 1
          ;;
      esac
      if [ "$avail_kib" -lt "$min_free_kib" ]; then
        log "ERROR: only $((avail_kib / 1024)) MiB free on $dst, need $((min_free_kib / 1024)) MiB"
        exit 1
      fi

      # Staging — на той же ФС, что и dst: финальный mv не копирует данные.
      workdir="$(mktemp -d "$dst/.staging.XXXXXX")"
      stage="$workdir/tree"
      mkdir -p "$stage"

      copy_path() {
        local rel="$1"
        [ -e "$src/$rel" ] || return 0
        mkdir -p "$(dirname "$stage/$rel")"
        cp -a -- "$src/$rel" "$stage/$rel"
      }

      # Корневые данные: скиллы целиком (включая .hub/.bundled_manifest),
      # память, персона и конфиги.
      copy_path skills
      copy_path memories
      copy_path SOUL.md
      copy_path profile.yaml
      copy_path config.yaml

      # Профили: только skills/memories/SOUL.md, без сессий и кешей.
      for pdir in "$src"/profiles/*/; do
        [ -d "$pdir" ] || continue
        pname="$(basename "$pdir")"
        for item in skills memories SOUL.md; do
          [ -e "$pdir$item" ] || continue
          mkdir -p "$stage/profiles/$pname"
          cp -a -- "$pdir$item" "$stage/profiles/$pname/$item"
        done
      done

      # Консистентный снимок SQLite: .backup через read-only URI, без копирования
      # -wal/-shm. Снимок сразу кладётся в staging, поэтому в архив попадает
      # целый файл, а не «живая» база.
      backup_db() {
        local rel="$1"
        [ -f "$src/$rel" ] || return 0
        mkdir -p "$stage/$(dirname "$rel")"
        rm -f -- "$stage/$rel"
        sqlite3 "file:$src/$rel?mode=ro" ".backup '$stage/$rel'"
        chmod 0600 "$stage/$rel"
      }

      backup_db state.db
      for db in "$src"/profiles/*/state.db; do
        [ -f "$db" ] || continue
        backup_db "''${db#"$src"/}"
      done

      # Никаких локов, кешей и секретов в архиве.
      find "$stage" -type f -name '*.lock' -delete
      find "$stage" -type f \( -name '.env' -o -name '.env.*' -o -name 'auth.json*' \) -delete
      find "$stage" -type d \( -name cache -o -name sandboxes -o -name sessions -o -name logs -o -name .claude \) -prune -exec rm -rf -- {} +

      # После staging проверяем, что на той же ФС хватит места на архив
      # (payload) плюс 512 MiB запаса.
      need_kib="$(du -sk "$stage" | cut -f1)"
      avail_kib="$(df --output=avail -k "$dst" | tail -n 1 | tr -d '[:space:]')"
      case "$avail_kib" in
        ""|*[!0-9]*)
          log "ERROR: cannot determine free space on $dst"
          exit 1
          ;;
      esac
      if [ "$avail_kib" -le $((need_kib + reserve_kib)) ]; then
        log "ERROR: payload needs $need_kib KiB plus $((reserve_kib / 1024)) MiB reserve, only $avail_kib KiB free on $dst"
        exit 1
      fi

      stamp="$(date -u +%Y%m%d-%H%M%S)"
      archive="$dst/hermes-knowledge-$stamp.tar.gz"
      tmp="$archive.tmp"
      tar -C "$stage" -czf "$tmp" .
      chmod 0600 "$tmp"
      if [ "$(id -u)" -eq 0 ]; then
        chown "$backup_user:users" "$tmp"
      fi
      mv -f -- "$tmp" "$archive"
      tmp=""
      log "created $archive"

      # Retention: оставляем keep самых свежих архивов (минимум 1), остальные
      # удаляем. .lock и .staging.* под шаблон не попадают.
      find "$dst" -maxdepth 1 -type f -name 'hermes-knowledge-*.tar.gz' -printf '%T@ %p\n' \
        | sort -rn \
        | tail -n +$((keep + 1)) \
        | cut -d' ' -f2- \
        | while IFS= read -r old; do
            rm -f -- "$old"
            log "removed old archive $old"
          done
    '';
  };

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

    # Живой журнал хоста — только на чтение. В образе контейнера (ubuntu:24.04
    # + первичный provisioning) нет ни journalctl, ни systemctl, поэтому журнал
    # читаем хостовым Nix-собранным journalctl из ro-монтирования /nix/store.
    # Нужен НЕ minimal-билд: минимальный собран без zstd и не читает
    # zstd-сжатые файлы журнала хоста. Файлы журнала — 0640 root:systemd-journal,
    # а контейнер работает под uid 986, поэтому внутри контейнера нужен
    # `sudo -n` (passwordless); `docker exec -u root` работает без sudo.
    # Список оставляем расширяемым: сюда же добавляются будущие ro-монтирования.
    # Никаких rw-монтирований хостовых путей здесь быть не должно.
    # /hostdiag — снимки hermes-hostdiag: база root-owned и смонтирована только
    # на чтение, поэтому агент не может подменить в ней файлы симлинками.
    # /usr/share/zoneinfo НЕ монтируется. В образе ubuntu:24.04 нет tzdata
    # (каталога /usr/share/zoneinfo просто нет), поэтому один лишь TZ=...
    # glibc молча игнорирует и падает в UTC — именно поэтому раньше сюда
    # ro-монтировали /etc/zoneinfo. Но такое монтирование ломает первичный
    # provisioning: entrypoint ставит nodejs, тот тянет tzdata, а dpkg не может
    # распаковать пакет в read-only каталог. 2026-10-23: tzdata 2026e →
    # `unable to create '/usr/share/zoneinfo/Africa/Abidjan.dpkg-new':
    # Read-only file system` → entrypoint exit 100 → systemd start-limit-hit,
    # контейнер лёг. Контракт: tzdata приходит из собственного provisioning
    # контейнера (архив Ubuntu), хост даёт только TZ=${vars.timezone} (см.
    # extraOptions ниже). Монтирование поверх /usr/share/zoneinfo не возвращать.
    # Инвариант «никаких rw-монтирований хостовых путей» сохранён: mount убран,
    # а не переведён в rw.
    container.extraVolumes = [
      "/var/log/journal:/host-journal:ro"
      "/var/lib/hermes-hostdiag:/hostdiag:ro"
    ];

    # /dev/kvm — аппаратное ускорение Android-эмулятора. Без KVM
    # qemu-system-x86_64 уходит в TCG (`-accel off`): гость не
    # загружается (7 минут, load average 10+, 190% CPU). На хосте
    # устройство crw-rw-rw- root:kvm, поэтому --group-add не нужен —
    # блокирует именно device-cgroup Docker. extraOptions входит в
    # containerIdentity, так что контейнер пересоздастся при рестарте
    # сервиса; тома /data и /home/hermes при этом сохраняются.
    container.extraOptions = [
      "--device" "/dev/kvm"
      # TZ обязателен: без него glibc берёт /etc/localtime образа (UTC), а
      # само монтирование базы зон пояс не переключает. vars.timezone —
      # единственный источник правды, общий с хостовым time.timeZone.
      "--env" "TZ=${vars.timezone}"
    ];

    # Даём текущему пользователю CLI `hermes` в PATH и writable-симлинк
    # ~/.hermes (конфиг/состояние живут в /var/lib/hermes, HERMES_HOME=/var/lib/hermes/.hermes).
    addToSystemPackages = true;
    container.hostUsers = [ vars.username ];

    # Вариант пакета: messaging (+~33 MB к замыканию) вместо default/full.
    # full тяжелее примерно на ~700 MB и тянет voice/tts-premium/matrix/
    # azure/bedrock — здесь они не нужны; недостающие extras контейнер доставит сам.
    # Нужны voice/tts/matrix — переключить на .default (или .tui).
    package = hermesPkg;

    # Дотягиваем python-extra `anthropic` в замыкание пакета. Без него 9 моделей
    # на Go-релее (claude-haiku-5-5, minimax-m2.5/m2.7/m3, qwen3.6-plus,
    # qwen3.7-plus/3.7-max, qwen3.8-max, qwen3.8-flash) падают с «The 'anthropic'
    # package is required»: они идут по anthropic-wire (/zen/go/v1/messages), а
    # venv лежит в /nix/store (read-only) и lazy-install в managed-режиме
    # запечатан. Рантайм-обход невозможен: sys.path фиксируется при старте
    # интерпретатора, а окружение контейнера приходит из docker run.
    # Это единственный Nix-кусок, который даёт модели «из коробки».
    # ВАЖНО: `package` выше — это вариант `.messaging`, т.е. уже
    # `minimal.override { extraDependencyGroups = [ "messaging" ]; }`.
    # Модуль применяет наш override поверх него, и `extraDependencyGroups`
    # ЗАМЕНЯЕТ список, а не дополняет его: с одним `[ "anthropic" ]` из
    # замыкания выпадали python-telegram-bot/discord.py/slack-sdk и гейтвей
    # падал с «No adapter available for enabled telegram». Поэтому перечисляем
    # обе группы явно.
    extraDependencyGroups = [ "messaging" "anthropic" ];

    # ── Маршрутизация LLM ───────────────────────────────────────────────────
    #
    # Основной маршрут — подписка Claude через плагин
    # claude-subscription-directsdk-experimental (sonnet-5-5). При
    # rate-limit/ошибке авторизации per-turn failover уходит на платный релей
    # OpenCode Go, последним эшелоном — платный DeepSeek.
    # `model.provider` принимает голый id встроенного провайдера (префикс
    # `custom:` нужен только для собственных эндпоинтов), а блоки
    # `providers.<имя>` для встроенных провайдеров не требуются вовсе.
    # Значения берутся из let-блока выше (hermesMain/hermesMainFallbacks/
    # hermesAuxiliary): тот же набор пишется в именованные профили активацией
    # hermes-agent-profile-routing, поэтому правки делаются в одном месте.
    # settings рендерится через builtins.toJSON в $HERMES_HOME/config.yaml
    # (JSON — это корректный YAML), вложенные attrsets → YAML-ключи 1:1.
    settings = {
      # Часы самого Hermes (system prompt, cron, дочерние процессы) берутся из
      # ключа timezone конфига, а не из TZ окружения. Задаём явно, чтобы они
      # совпадали с TZ контейнера: источник правды один — vars.timezone.
      timezone = vars.timezone;

      model = {
        provider = hermesMain.provider;
        default = hermesMain.default;

        # Псевдонимы для осознанного выбора модели: `/model strong`, `-m fast`,
        # отдельный прогон `hermes chat -m <alias>`. Формат — provider/model.
        # Набор отобран по публичным замерам (Artificial Analysis Intelligence
        # Index v4.3.2, LMArena/swfte, Terminal-Bench 4.0, DeepSWE v1.1), а не
        # по вкусу: цифры в комментариях — оттуда.
        aliases = {
          # AA 42, 117 t/s, самый дешёвый из «хороших»: рутина, извлечение, логи.
          fast = "opencode-go/glm-5.3-flash";
          # AA 51 при 168 t/s (втрое быстрее K3): сильный и быстрый одновременно.
          mid = "opencode-go/glm-5.2";
          # AA 57 — топ-4 в мире, лучший общий интеллект. Архитектура, сложное.
          strong = "opencode-go/kimi-k3";
          # Специализированная кодовая модель.
          code = "opencode-go/kimi-k2.7-code";
          # AA 46, Terminal-Bench 4.0 = 34.9 — лучший open-weight на агентных
          # терминальных задачах. Многошаговые агентные прогоны.
          mimo = "opencode-go/mimo-v2.6-pro";
          # 1M контекста: огромные репозитории/логи.
          qwen = "opencode-go/qwen3.8-max";
          # $0.1/0.5, quality 89: массовая дешёвая рутина, мультимодалка.
          luna = "opencode-go/gpt-6-luna";
          # 500k, responses-wire.
          grok = "opencode-go/grok-4.7";
        };

        # НЕ заводим алиасов (сознательно):
        #  * deepseek-v4-pro — по решению владельца хуже 4.1-flash;
        #  * mimo-v2.5-pro — провал (DeepSWE 19.0, Terminal-Bench 2.1 = 1.5);
        #  * hy3 — quality 76, заметно слабее линейки;
        #  * gemini-4-argon-contributor — есть в каталоге, но релей отдаёт
        #    400 ModelProtocolUnsupported на всех трёх wire (chat/responses/
        #    messages) и Google-эндпоинта нет (404).
      };

      # Штатный per-turn failover Hermes: при rate-limit/ошибке сервера/
      # авторизации (в т.ч. исчерпанный лимит подписки Claude) сессия
      # переключается по цепочке ниже и возвращается обратно на следующий ход.
      # Для встроенных провайдеров достаточно provider + model
      # (base_url/key_env наследуются); запись без любого из этих полей
      # игнорируется. fallback.min_switch_reset_seconds = 0 по умолчанию —
      # переключаемся сразу.
      # Порядок = приоритет: сначала добираем подписку Go другими моделями
      # (дешёвая flash → сильные), и только потом платный DeepSeek.
      # При лимите primary уходит в cooldown (до сброса у провайдера или
      # экспоненциальный бэкофф) и запрос идёт по цепочке вниз.
      fallback_providers = hermesMainFallbacks;

      # Вспомогательные задачи: общий набор для root/default и профилей.
      auxiliary = hermesAuxiliary;

      # MCP: Outline — статический API-ключ вместо OAuth.
      #
      # Outline 1.10.1 ротирует refresh-токен на каждый refresh и привязывает
      # его к DCR-client_id. Hermes v0.22.2 при invalid_client удаляет
      # .client.json, но оставляет токены (upstream #109852, фикс-PR #109853 не
      # влит), поэтому следующий refresh уходит со старым refresh-токеном и новым
      # client_id → Outline отвечает 400 «refresh token was issued to another
      # client», грант уничтожается, и в неинтерактивном контейнере остаётся
      # только ручной `hermes mcp login outline` каждый час.
      # Outline принимает на /mcp обычный `Authorization: Bearer <ol_api_…>`,
      # поэтому OAuth здесь не нужен вовсе.
      #
      # Ключ НЕ в сторе: он лежит в /etc/hermes-agent/env, который объявлен в
      # environmentFiles НИЖЕ (после settings) и попадает в $HERMES_HOME/.env при активации;
      # раскрывается загрузчиком MCP-конфига (только фигурные скобки, не $VAR).
      # auth = "none" обязателен: при auth: oauth провайдер OAuth перезаписывает
      # статический заголовок своим access-токеном.
      # protocol = "legacy": только initialize, без server/discover с версией
      # 2026-07-28, которую Outline 1.10.1 не объявляет.
      mcp_servers.outline = {
        url = "https://outline.tsai.tech/mcp";
        headers.Authorization = "Bearer \${OUTLINE_API_KEY}";
        auth = "none";
        protocol = "legacy";
      };

      # Согласие на data-training tier (gemini-4-argon-contributor): без него
      # Hermes в non-interactive режиме отказывается запускать модель.
      # Решение пользователя: согласие дано. Отозвать — удалить ключ.
      security = {
        allow_data_training_tiers_noninteractive = true;
      };

      # ── Про бесплатные модели на Go-релее ───────────────────────────────
      # Go-релей — второй эшелон после подписки Claude. Когда месячный бюджет
      # Go на deepseek-v4.1-flash исчерпан, бесплатные модели остаются
      # доступны именно через Go-релей, и их можно поставить следующим
      # эшелоном (записью в fallback_providers выше). Точные id бесплатных
      # моделей НЕ хардкодить здесь — читать из каталога:
      #   GET https://opencode.ai/zen/go/v1/models
      # (в списке искать id, содержащие `free`).
    };

    # Ключи провайдера живут в /etc/hermes-agent/env (root:root, 0600) — файл
    # создаёт наш activation-скрипт ниже, в стор и в git он не попадает.
    # Содержимое — по одной переменной вида KEY=value на строку (inline-комментарии
    # в самом файле не использовать). Рекомендуемое содержимое целиком:
    #
    #   OPENCODE_GO_API_KEY=<oc_sk_…>
    #   OPENCODE_ZEN_API_KEY=${OPENCODE_GO_API_KEY}
    #   DEEPSEEK_API_KEY=<ключ DeepSeek>
    #
    # Почему два имени, а значение одно: opencode-go и opencode-zen — два
    # отдельных ВСТРОЕННЫХ провайдера Hermes, и каждый читает строго своё имя
    # (plugins/model-providers/opencode-go/__init__.py:126 → OPENCODE_GO_API_KEY;
    # opencode-zen/__init__.py:120 → OPENCODE_ZEN_API_KEY). Общей переменной
    # OPENCODE_API_KEY в апстриме нет, а remap key_env встроенного провайдера из
    # Nix невозможен. Поэтому полный токен вписывается ровно один раз — теперь в
    # OPENCODE_GO_API_KEY (основной эшелон Go-релея), — а вторая строка лишь ссылается
    # на него. Загрузчик .env раскрывает ${VAR} по порядку
    # (hermes_cli/env_loader.py:359-364), поэтому значение физически лежит в
    # одном месте, в первой строке; переменную объявлять ДО ссылки на неё.
    #
    #   DEEPSEEK_API_KEY=<ключ>    — нужен только для платного фолбэка,
    #                                https://platform.deepseek.com/api_keys.
    #
    # Откуда opencode-токен: service-account key в консоли OpenCode
    # (https://opencode.ai/console → Keys → Add Service Account → Add API Key,
    # Permissions = «Inference only», формат oc_sk_…). Ключ привязан к
    # workspace, и один и тот же ключ годится и для Go, и для Zen. Право на Go
    # даёт НЕ ключ, а активная Go-подписка на том же workspace: тот же ключ без
    # подписки отвечает Invalid credential. Собственный креденшл локального CLI
    # лежит отдельно, в ~/.local/share/opencode/auth.json, и контейнеру не
    # подходит — в /etc/hermes-agent/env нужен именно console-ключ.
    #
    # Про бесплатный тир (403 FreeTierError): подтверждено, что free-маршрут
    # недостижим для сторонних клиентов — на /zen/v1/chat/completions любой
    # запрос извне OpenCode получает 403 FreeTierError (User-Agent,
    # x-opencode-session, referer и x-title не помогают). Не тратить на него
    # время. Free-модели при этом остаются доступны именно ЧЕРЕЗ Go-релей —
    # когда месячный бюджет Go исчерпан (см. заметку про fallback выше).
    # Что искать в логах:
    #   FreeTierError              → клиент упёрся в free-тир (ожидаемо вне
    #                                 OpenCode; для Go-релея с рабочим ключом —
    #                                 не должно быть);
    #   MissingSessionID           → 400: Go-релей не увидел x-opencode-session;
    #                                 Hermes v0.22.2 шлёт его сам на opencode.ai-
    #                                 хостах, так что это признак старой версии;
    #   AuthError: Missing API key. → токен не дошёл до контейнера (проверить
    #                                 /etc/hermes-agent/env и перезапуск);
    #   Invalid credential          → токен есть, но не принят (проверить
    #                                 workspace/срок жизни ключа и активную
    #                                 Go-подписку на этом workspace).
    #
    # OPENCODE_ZEN_BASE_URL  — запасной выход, если релей /zen/v1 сменит путь:
    #                          Hermes использует её как переопределение базы
    #                          (например, https://opencode.ai/inference/openai/v1).
    # OPENCODE_GO_BASE_URL   — то же самое для opencode-go.
    #
    # Записать ключи и применить (контейнер НЕ пересоздаётся):
    #   sudoedit /etc/hermes-agent/env
    #   sudo systemctl restart hermes-agent
    #
    # ВАЖНО: активация ДОПИСЫВАЕТ содержимое файла к $HERMES_HOME/.env, но сам
    # .env каждый раз пересоздаётся с нуля (`install -m ... base $dest` в
    # апстримном mkEnvScript), поэтому ключ, вписанный руками прямо в .env,
    # теряется при первом же nixos-rebuild. Rebuild переживает только
    # /etc/hermes-agent/env. Отсутствующий/пустой файл активацию не ломает
    # (`if [ -r "$file" ]` → WARNING и дальше).
    # desktop-token.env — токен панели для pure-client десктопа. Активация
    # дописывает его в $HERMES_HOME/.env ДО импорта web-сервера, поэтому сервер
    # берёт токен из окружения, а не генерирует случайный. Файл создаёт
    # hermes-agent-envfile ниже; тот же файл читает обёртка десктопа.
    environmentFiles = [
      "/etc/hermes-agent/env"
      "/etc/hermes-agent/desktop-token.env"
    ];

    # GPU в контейнер не пробрасываем: llama.cpp крутится на хосте, а не здесь.
    # Если агенту понадобится локальная RTX 4080, добавить:
    #   container.extraOptions = [ "--gpus" "all" ];
  };

  # ── `claude` в PATH контейнера для плагина directsdk ────────────────────────
  #
  # Плагин claude-subscription-directsdk-experimental не хранит путь к CLI:
  # directsdk_setup._resolve() на КАЖДЫЙ запрос делает shutil.which('claude')
  # по PATH (fallback — ~/.local/bin и соседние префиксы). В образе ubuntu:24.04
  # бинарника нет, поэтому интеграционная точка — этот симлинк.
  # L+ (а не L) переустанавливает ссылку на каждом nixos-rebuild switch:
  # прямая ссылка на hash-pinned store path устаревает после бампа claude-code
  # и умирает, когда старую сборку вычистит GC. /nix/store внутри контейнера
  # смонтирован ro (см. комментарий у services.hermes-agent), так что цель
  # видна и хосту, и контейнеру.
  systemd.tmpfiles.rules = [
    "d ${stateDir}/home/.local/bin 0755 hermes hermes -"
    "L+ ${stateDir}/home/.local/bin/claude - - - - ${pkgs.claude-code}/bin/claude"
  ];

  # Файл с ключами создаём сами, декларативно. systemd.tmpfiles.rules для этого
  # не годятся: активация (и чтение environmentFiles) выполняется РАНЬШЕ
  # tmpfiles — апстримный модуль сам это фиксирует («activation runs before
  # tmpfiles», nix/nixosModules.nix:461), а tmpfiles переигрываются отдельно
  # через systemd-tmpfiles-resetup.service / sysinit-reactivation.target.
  # Содержимое не трогаем — только существование, владелец и режим 0600.
  #
  # Здесь же — токен панели для десктопа (desktop-token.env). В Nix store его
  # класть нельзя (store читаем всем), поэтому генерируем рантайм-файл.
  # Существующий НЕПУСТОЙ файл не перезаписываем: токен обязан переживать
  # rebuild, иначе сервер и приложение разойдутся. Файл читают оба: бэкенд
  # (через environmentFiles) и обёртка hermes-desktop. 0640 root:hermes —
  # десктоп работает от пользователя из группы hermes, остальным незачем.
  system.activationScripts.hermes-agent-envfile = {
    deps = [ "etc" ];
    text = ''
      install -d -m 0755 /etc/hermes-agent
      if [ ! -e /etc/hermes-agent/env ]; then
        install -m 0600 /dev/null /etc/hermes-agent/env
      fi
      chmod 0600 /etc/hermes-agent/env
      # Симлинк на месте файла токена убираем: каталог root-only, но regenerate
      # не должен писать по чужому пути (chown/chmod ниже — с -h/--no-dereference).
      _hermes_token=/etc/hermes-agent/desktop-token.env
      if [ -L "$_hermes_token" ]; then
        rm -f -- "$_hermes_token"
      fi
      # Пересоздаём не только отсутствующий/пустой файл, но и усечённый: без
      # непустой строки HERMES_DASHBOARD_SESSION_TOKEN= десктоп навсегда
      # завершается с кодом 1. grep явно из gnugrep — в PATH активации его нет.
      if ! ${pkgs.gnugrep}/bin/grep -q '^HERMES_DASHBOARD_SESSION_TOKEN=.\+' "$_hermes_token" 2>/dev/null; then
        # umask в активации общий (0022), поэтому сужаем его в подоболочке —
        # иначе файл с токеном успел бы стать 0644.
        (
          umask 077
          printf 'HERMES_DASHBOARD_SESSION_TOKEN=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" \
            > "$_hermes_token"
        )
      fi
      chown -h "root:${config.services.hermes-agent.group}" "$_hermes_token"
      chmod --no-dereference 0640 "$_hermes_token"
    '';
  };
  # Апстримный hermes-agent-setup читает environmentFiles, поэтому обязан идти
  # после нас (deps склеиваются: ["users" ...] ++ ["hermes-agent-envfile"]).
  system.activationScripts.hermes-agent-setup.deps = [ "hermes-agent-envfile" ];

  # ── Пин маршрутизации в именованных профилях ────────────────────────────────
  #
  # Идёт после hermes-agent-setup: тот создаёт каталоги профилей и сам
  # config.yaml. Контейнер при этом запускать не нужно — файлы лежат на хосте.
  # Скрипт запускается от непривилегированного hermes через runuser: дерево
  # profiles принадлежит контейнерному пользователю, поэтому root не должен
  # читать/писать по возможным симлинкам. При euid != 0 chown не делается
  # (владелец и так hermes), режим 0660 выставляется. Скрипт проверяет lstat'ом
  # каждый компонент пути и пропускает профиль, если что-то подменено ссылкой.
  # Профиль без config.yaml пропускается, ошибка одного профиля логируется и
  # не валит активацию; фатальные ошибки (нет payload, нет runuser) валят
  # rebuild. Скрипт и payload — в let-блоке выше (hermesProfileRouting).
  system.activationScripts.hermes-agent-profile-routing = {
    deps = [ "hermes-agent-setup" ];
    text = ''
      ${pkgs.util-linux}/bin/runuser -u ${config.services.hermes-agent.user} -- \
        ${hermesProfileRouting} ${hermesHome} ${hermesProfileRoutingPayload}
    '';
  };

  # ── Права на $HERMES_HOME (=${stateDir}/.hermes) ───────────────────────────
  #
  # Хостовый CLI (пользователь из container.hostUsers) читает
  # $HERMES_HOME/.container-mode, чтобы понять, что команду надо выполнять в
  # контейнере; для этого нужен traverse-бит на самом каталоге .hermes.
  # Апстримный модуль объявляет этому каталогу 2770 hermes:hermes
  # (systemd.tmpfiles.rules + активация в nixosModules.nix) — именно чтобы CLI
  # у члена группы hermes имел доступ. Но сам Hermes возвращает 0700: при
  # записи auth.json, лежащего ПРЯМО в $HERMES_HOME, вызывается
  # hermes_cli/auth.py:_save_private_json → hermes_constants.py:
  # secure_parent_dir(), который жёстко делает chmod(parent, 0o700) и, в
  # отличие от соседнего apply_secure_dir_policy(), НЕ учитывает managed/
  # container-режим. Итог: после первой же записи auth store (первый boot,
  # логин, ротация креденшла) каталог снова 0700, и `hermes config …` падает с
  # PermissionError: [Errno 13] на /home/${vars.username}/.hermes/.container-mode.
  #
  # Идём ПОСЛЕ апстримного hermes-agent-setup и возвращаем объявленный апстримом
  # режим: 2770 (setgid — чтобы runtime-подкаталоги наследовали группу hermes).
  # Порядок «сначала chown, потом chmod» важен: chown сбрасывает setgid.
  # Группа — только hermes, для остальных нуль: в каталоге лежат auth.json,
  # .env и sessions, поэтому world-readable здесь недопустим. Цена решения:
  # CLI работает только у членов группы hermes (это и есть контракт
  # container.hostUsers) — сторонние пользователи хоста в $HERMES_HOME не
  # попадают. Файлы-секреты (.env, auth.json) и их режимы не трогаем.
  #
  # Остаточный риск: любая запись auth.json в рантайме снова ставит 0700.
  # Активация чинит это только при switch/boot, поэтому ниже режим возвращают
  # два независимых юнита, оба — через один и тот же guarded-сервис:
  #   * systemd.paths.hermes-agent-state-perms  — событийно, реакция сразу;
  #   * systemd.timers.hermes-agent-state-perms — раз в минуту, бэкстоп;
  # аварийная ручная разблокировка без sudo (leet в группе docker):
  #   docker exec hermes-agent chmod 2770 /data/.hermes
  # Полностью лечится только апстримом: secure_parent_dir() должен уважать
  # managed-режим так же, как apply_secure_dir_policy().
  system.activationScripts.hermes-agent-state-perms = {
    deps = [ "hermes-agent-setup" ];
    text = hermesStatePermsCmd;
  };

  # ── Периодический возврат режима на $HERMES_HOME ────────────────────────────
  #
  # Зачем: активация отрабатывает только при nixos-rebuild switch/boot, а
  # апстримный secure_parent_dir() ставит 0700 в рантайме — при каждой записи
  # $HERMES_HOME/auth.json (логин, ротация/refresh креденшла). Между этими
  # событиями хостовый CLI молча ломается с PermissionError на .container-mode
  # (подробный разбор — в комментарии к активации выше).
  #
  # ЗАПРЕТ: НЕ ДОБАВЛЯТЬ PathExists — ни сюда, ни в path-юнит ниже!
  # Первая версия (2026-10-17, откачена) слушала auth.json через
  # pathConfig.PathChanged + PathExists. PathExists — условие УРОВНЕВОЕ: пока
  # файл существует, условие истинно, поэтому сразу после завершения сервиса
  # systemd перевооружал watch и стартовал сервис снова; ≥5 стартов внутри
  # дефолтного StartLimitIntervalSec=10 с → «Start request repeated too
  # quickly» → start-limit-hit у сервиса + unit-start-limit-hit у path-юнита →
  # switch-to-configuration счёл новый юнит упавшим и завершил активацию с
  # 4/NOPERMISSION (при этом каждый отдельный запуск сервиса был
  # status=0/SUCCESS). Именно поэтому у сервиса стоит
  # StartLimitIntervalSec=0: любой непредусмотренный шторм теперь безвреден.
  #
  # PathChanged (см. path-юнит ниже) — наоборот, событийный (edge) триггер: он
  # срабатывает только на реальное изменение, а не на «условие истинно»,
  # поэтому шторма не даёт. Таймер при этом остаётся бэкстопом на случай, если
  # path-юнит не сможет встать на watch.
  #
  # Значения таймера: OnBootSec=30 s — первый re-assert вскоре после boot (на
  # уже работающей системе этот момент в прошлом, поэтому при (пере)запуске
  # таймера сервис срабатывает сразу, и после nixos-rebuild switch состояние
  # чинится немедленно). OnUnitActiveSec=1 min — периодический re-assert:
  # худшее время восстановления CLI ≈ 1 мин + AccuracySec. AccuracySec=30 s —
  # systemd может сдвигать срабатывание в пределах окна, чтобы будить CPU вместе
  # с другими таймерами; дефолтная 1 min дала бы худший случай ~2 мин, что для
  # «CLI молча сломался» многовато.
  #
  # Сервис не должен уметь ни завалить пересборку, ни «залипнуть»:
  #  * unitConfig.StartLimitIntervalSec = 0 — документированный systemd способ
  #    выключить rate limiting, поэтому start-limit-hit невозможен даже при
  #    массовых перезапусках. Безопасно: команда идемпотентна и не трогает
  #    ничего, что её же триггерит (только метаданные одного каталога).
  #  * скрипт (см. let выше) делает chown/chmod только при неверном состоянии,
  #    а при отсутствии каталога молча выходит с нулём.
  #  * сервис нигде не «wanted» и запускается только таймером через Unit=,
  #    поэтому в момент switch стартует лишь таймер — мгновенно и без сбоев.
  systemd.services.hermes-agent-state-perms = {
    description = "Return group traverse (2770) on the Hermes state dir (HERMES_HOME)";
    # root по умолчанию: каталог принадлежит hermes, chown/chmod по чужому пути.
    serviceConfig.Type = "oneshot";
    unitConfig.StartLimitIntervalSec = 0;
    script = hermesStatePermsCmd;
  };

  systemd.timers.hermes-agent-state-perms = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "hermes-agent-state-perms.service";
      OnBootSec = "30s";
      OnUnitActiveSec = "1min";
      AccuracySec = "30s";
    };
  };

  # ── Мгновенная реакция на сброс режима (событийный триггер) ─────────────────
  #
  # Таймер выше лечит каталог с задержкой до ~1.5 мин. Здесь — быстрый путь:
  # watch на сам каталог, срабатывает в ту же секунду, когда Hermes переписал
  # auth.json (атомарная замена файла = событие в каталоге).
  #
  # Только PathChanged, без PathExists: PathChanged — событийный (edge) триггер,
  # он не «истинен постоянно», поэтому не может устроить storm из прошлого
  # инцидента (см. комментарий выше). Петли тоже нет: сервис guarded — при уже
  # верном режиме он не делает ни chown, ни chmod, то есть не порождает
  # метаданных-событий, на которые мог бы среагировать сам.
  #
  # StartLimitIntervalSec=0 на самом path-юните — вторая страховка: даже если
  # каталог начнут менять сотнями событий в секунду, systemd не откажется
  # запускать сервис (а лишние запуски — дешёвые no-op).
  systemd.paths.hermes-agent-state-perms = {
    wantedBy = [ "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;
    pathConfig = {
      Unit = "hermes-agent-state-perms.service";
      PathChanged = hermesHome;
    };
  };

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

  # ── Веб-панель (браузерный интерфейс без команд) ────────────────────────────
  #
  # `hermes dashboard` — SPA + backend: чат с агентом, сессии, cron, kanban,
  # MCP, память, файлы, терминалы, настройки. Слушает ТОЛЬКО loopback:
  # локальный биндинг не требует аутентификации, а публичный биндинг с июня
  # 2026 всегда требует auth-провайдера (флаг --insecure больше ничего не
  # отключает), поэтому наружу не биндим — для телефона есть SSH-туннель:
  #   ssh -L 9119:127.0.0.1:9119 <user>@<host>
  #
  # Запускаем ВНУТРИ контейнера от uid/gid пользователя hermes: под root
  # процесс создал бы root-owned файлы в $HERMES_HOME и гейтвей (uid hermes)
  # потерял бы к ним доступ. --skip-build: dist уже собран в пакете
  # (share/hermes-agent/web_dist), npm в контейнере не нужен.
  #
  # Первый ExecStartPre (hermesDashboardWait) ждёт готовности контейнера:
  # after/requires недостаточно, потому что hermes-agent Type=simple и активен
  # ещё до того, как entrypoint создаст пользователя hermes. См. комментарий у
  # hermesDashboardWait. TimeoutStartSec больше таймаута ожидания (120 с):
  # иначе systemd убил бы юнит раньше и вместо понятного сообщения об
  # отсутствии пользователя в журнале был бы голый «start operation timed out».
  #
  # Второй ExecStartPre со «-» гасит забытый вручную экземпляр — иначе порт
  # занят и юнит уходил бы в рестарт-луп. Restart=always безопасен: у панели нет
  # idle-выхода (idle-watchdog включается только для SSH-изолированных
  # бэкендов).
  systemd.services.hermes-dashboard = {
    description = "Hermes Agent web dashboard (http://127.0.0.1:9119)";
    after = [ "hermes-agent.service" ];
    requires = [ "hermes-agent.service" ];
    # Перезапуск гейтвея = рестарт контейнера = смерть всех процессов внутри,
    # включая панель. PartOf перезапускает и её, иначе порт остался бы мёртвым.
    partOf = [ "hermes-agent.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      TimeoutStartSec = 150;
      ExecStartPre = [
        "${pkgs.bash}/bin/bash ${hermesDashboardWait}"
        "-${config.virtualisation.docker.package}/bin/docker exec -u hermes hermes-agent ${hermesPkgBin} dashboard --stop"
      ];
      # -u hermes: docker резолвит имя внутри контейнера (/etc/passwd: hermes
      # 986:981), поэтому не хардкодим uid и не зависим от null в опциях модуля.
      # 127.0.0.1 — не случайно: на loopback Hermes НЕ включает basic-auth гейт
      # (auth_required false), а именно гейт отвергает X-Hermes-Session-Token
      # (401). Десктоп ходит в панель как pure-client по этому же loopback и с
      # токеном из desktop-token.env. Снаружи панели больше нет: с телефона —
      # только SSH-туннель: ssh -L 9119:127.0.0.1:9119 <user>@<host>
      ExecStart = "${config.virtualisation.docker.package}/bin/docker exec -u hermes hermes-agent ${hermesPkgBin} dashboard --no-open --skip-build --host 127.0.0.1 --port 9119";
      ExecStop = "${config.virtualisation.docker.package}/bin/docker exec -u hermes hermes-agent ${hermesPkgBin} dashboard --stop";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # ── Ежедневный бэкап базы знаний Hermes Agent ──────────────────────────────
  #
  # Root нужен, чтобы прочитать profiles/* с режимом 0700 (владелец hermes).
  # Сервис запускается только таймером; Nice/IOSchedulingClass уводят I/O
  # архивации на задний план. Скрипт сам проверяет место и делает retention.
  #
  # RequiresMountsFor — директива секции [Unit], поэтому она в unitConfig:
  # в serviceConfig NixOS отрендерил бы её в [Service], а systemd такие
  # директивы игнорирует (проверено systemd-analyze verify). Без этого при
  # недоступном /home/leet/Storage (nofail) install -d создал бы каталог
  # бэкапов на корневой ФС.
  #
  # ProtectSystem=full, а не strict: read-only /var ломает SQLite WAL —
  # read-only соединению нужен writable -shm, который SQLite создаёт при
  # первом открытии (особенно когда gateway остановлен и -shm уже удалён).
  systemd.services.hermes-knowledge-backup = {
    description = "Daily backup of the Hermes Agent knowledge base";
    unitConfig.RequiresMountsFor = [ "/home/leet/Storage" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Nice = 10;
      IOSchedulingClass = "idle";
      # /usr, /boot, /etc read-only; /var остаётся writable ради -shm/-wal.
      # ReadWritePaths документирует единственный намеренный путь записи.
      # umask в скрипте дополнительно страхует режимы файлов.
      UMask = "0077";
      PrivateTmp = true;
      ProtectSystem = "full";
      NoNewPrivileges = true;
      ReadWritePaths = [ "/home/leet/Storage" ];
      ExecStart = lib.getExe hermesKnowledgeBackup;
    };
  };

  systemd.timers.hermes-knowledge-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "hermes-knowledge-backup.service";
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };

  # ── OpenCode ────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    opencode-desktop
    opencode
    hermesIcon
    hermesDesktopBin
    hermesDesktopItem
  ];
}
