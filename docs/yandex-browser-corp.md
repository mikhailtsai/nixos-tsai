# Корпоративный Яндекс Браузер на NixOS

Инструкция по установке и регистрации корпоративного Яндекс Браузера из ZIP-архива, предоставленного компанией.

## Файлы в архиве

Компания предоставляет ZIP с тремя DEB-пакетами:
- `YandexBrowser.deb` — сам браузер
- `yandex-browser-customisation.deb` — корпоративные настройки и partner_config
- `yandex-browser-licence.deb` — лицензионный файл

## Установка

### 1. Распаковать ZIP

```bash
unzip LinuxDEB-YandexBrowser.zip -d /tmp/yb-install/
```

### 2. Распаковать DEBs в /opt/yandex-browser

На NixOS нет `dpkg`, поэтому распаковываем вручную через `ar` + `tar`:

```bash
sudo mkdir -p /opt/yandex-browser

# Основной браузер
cd /tmp/yb-install && ar x YandexBrowser.deb
sudo tar -xf data.tar.xz -C /opt/yandex-browser/

# Корпоративная кастомизация
mkdir cust && cd cust && ar x /tmp/yb-install/yandex-browser-customisation.deb
sudo tar -xf data.tar.xz -C /opt/yandex-browser/

# Лицензия
mkdir lic && cd lic && ar x /tmp/yb-install/yandex-browser-licence.deb
sudo tar -xf data.tar.xz -C /tmp/yb-licence-data/
```

### 3. Права на директорию

```bash
sudo chmod 755 /opt/yandex-browser
sudo chmod -R o+rX /opt/yandex-browser/opt/yandex/browser/
```

### 4. Скопировать license и customisation на хостовый /var/lib

FHS-контейнер монтирует `/var` с хоста напрямую, поэтому файлы должны лежать
на хосте в `/var/lib/yandex/`, а не внутри `/opt/yandex-browser/var/`.

```bash
sudo mkdir -p /var/lib/yandex/browser-license
sudo mkdir -p /var/lib/yandex/browser-customization/Extensions
sudo mkdir -p /var/lib/yandex/browser-customization/resources

sudo cp /opt/yandex-browser/var/lib/yandex/browser-license/license \
        /var/lib/yandex/browser-license/license

sudo cp -r /opt/yandex-browser/var/lib/yandex/browser-customization/* \
           /var/lib/yandex/browser-customization/

sudo chmod -R a+rX /var/lib/yandex/
```

### 5. Политика enrollment (один раз при первой установке)

Токен enrollment берётся из письма, которое IT присылает на корп почту.
Письмо содержит ссылку вида:
```
yandex-corp-browser-open-url://?url=https%3A%2F%2Fregistration.browser.yandex.ru%2F%3F<ТОКЕН>
```

Создать файл политики с этим токеном:

```bash
sudo mkdir -p /etc/opt/yandex/browser/policies/managed
sudo tee /etc/opt/yandex/browser/policies/managed/enrollment.json <<EOF
{
  "YandexCloudEnrollment": {
    "enrollment_token": "<ТОКЕН_ИЗ_ПИСЬМА>"
  }
}
EOF
```

### 6. Пересобрать NixOS (если не было сделано)

FHS-обёртка в `modules/packages.nix` уже настроена:
- Пробрасывает `/etc/opt` в контейнер через `profile`-скрипт (симлинк `/.host-etc/opt`)
- Пробрасывает `/var` с хоста автоматически через `auto_mounts`

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Регистрация устройства

После установки и пересборки:

1. Запустить `yandex-browser`
2. Открыть ссылку из письма прямо в адресной строке браузера:
   ```
   https://registration.browser.yandex.ru/?<ТОКЕН>
   ```
   (браузер перехватывает этот домен внутренне)
3. При успехе браузер покажет "The browser is already registered"
4. Проверить статус: `browser://policy/` — статус должен быть Managed

## Почему не просто dpkg

На NixOS нет `dpkg`. DEB — это AR-архив с `data.tar.xz` внутри, поэтому
распаковка через `ar` + `tar` полностью эквивалентна `dpkg -x`.

## Обновление браузера

При получении нового ZIP от компании — повторить шаги 1–4.
Шаги 5–6 повторять не нужно (политика и enrollment сохраняются).
