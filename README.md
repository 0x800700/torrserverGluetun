# TorrServer + Gluetun (Cloudflare WARP)

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![VPN](https://img.shields.io/badge/VPN-Gluetun-green)](https://github.com/qdm12/gluetun)
[![GitHub Repo stars](https://img.shields.io/github/stars/0x800700/torrserverGluetun?style=social)](https://github.com/0x800700/torrserverGluetun)

## Описание проекта

Этот проект предназначен для использования TorrServer в связке с приложением Lampa на телевизоре (Android TV, webOS, Tizen и др.).

Связка **Lampa + TorrServer** позволяет:

- смотреть фильмы и сериалы напрямую из торрентов
- без предварительной загрузки всего файла целиком
- с перемоткой, паузой и выбором качества
- при этом TorrServer работает на отдельном компьютере / сервере, а телевизор выступает только клиентом

## Зачем здесь TorrServer + VPN (Gluetun)?

В данной конфигурации TorrServer:

- выходит в интернет через VPN
- загружает торрент-данные, трекеры и пиры через VPN-туннель
- но остаётся доступным в локальной сети по IP хоста и порту 8090

Это даёт:

- скрытие реального IP-адреса хоста
- возможный обход блокировок трекеров
- при этом никаких VPN на телевизоре или клиентских устройствах не требуется

### Схема доступа

```
Телевизор / Lampa → локальный IP сервера :8090 → TorrServer → VPN → Интернет
```

## Почему не оригинальный yourok/TorrServer + Gluetun

Под «оригинальным TorrServer» здесь подразумевается проект [YouROK/TorrServer](https://github.com/YouROK/TorrServer).

На практике при попытке запустить его совместно с Gluetun возникают архитектурные проблемы, а не «неправильные настройки».

### Основная проблема

Чаще всего TorrServer запускают с:

```yaml
network_mode: container:gluetun
```

Но этот режим означает, что контейнер:

- делит не только сеть
- но и файловую систему, PID namespace и окружение с контейнером Gluetun

В результате:

- TorrServer пытается запуститься в файловой системе Gluetun
- в образе Gluetun нет бинарника TorrServer
- возникает ошибка `not found`
- контейнер падает и уходит в бесконечный restart (`restart: unless-stopped`)

Это не баг TorrServer и не баг Gluetun, а фундаментальное ограничение режима `container:`.

**Почему это критично:**

- TorrServer теряет доступ к своим данным (accs.db, настройки, база)
- Невозможно стабильно обновлять бинарник
- Невозможно управлять пользователями и конфигурацией

### Что сделано в этом проекте

- TorrServer и Gluetun — разные контейнеры
- TorrServer использует свою файловую систему
- Весь исходящий трафик TorrServer идёт через Gluetun
- Архитектура стабильна и предсказуема

## Почему Cloudflare WARP

В этом проекте используется Cloudflare WARP по следующим причинам:

- Бесплатный тариф не режет P2P-трафик
- Достаточно высокая скорость
- Работает стабильно для TorrServer
- Не требует подписки для базового использования

### Альтернативы

Проект не привязан жёстко к Cloudflare. Gluetun поддерживает множество VPN-провайдеров:

- ProtonVPN
- Mullvad
- NordVPN
- WireGuard-конфиги от любых сервисов

Документация Gluetun: [qdm12/gluetun](https://github.com/qdm12/gluetun).

> **Примечание:** ProtonVPN тестировался — удобен тем, что сразу даёт готовый `wg0.conf`, но на бесплатном тарифе P2P ограничен, поэтому для TorrServer не подходит.

## Как работает скрипт

Скрипт автоматизирует весь процесс деплоя:

1. определяет архитектуру хоста (x86_64 или arm64)
2. скачивает соответствующий бинарник TorrServer (MatriX)
3. создаёт структуру каталогов
4. настраивает Gluetun (WireGuard)
5. создаёт accs.db с пользователем
6. запускает контейнеры через Docker Compose
7. при повторных запусках работает как меню управления

## Структура проекта

После установки весь проект живёт в одной папке:

```
.
├── docker-compose.yaml
└── opt/
    ├── gluetun/
    │   └── wg0.conf
    ├── torrserver/
    │   ├── bin/
    │   │   └── TorrServer
    │   └── db/
    │       └── accs.db
    └── certs/
        └── ca-certificates.crt
```

### Файл wg0.conf (WireGuard)

**PrivateKey:**

- Уникален для каждого пользователя
- Должен быть получен самостоятельно
- Обязателен для работы VPN

Получение ключа описано ниже.

**Остальные параметры:**

- `PersistentKeepalive = 25` — используется для поддержания соединения за NAT
- `Endpoint` — Gluetun не принимает доменные имена, только IPv4-адреса. Поэтому используется числовой IP Cloudflare
- IPv6 отключён — так как в данном сетапе не используется. При необходимости IPv6 его можно включить вручную в конфиге

### Файл accs.db (пользователи)

`accs.db` — это JSON-файл с учётными записями TorrServer.

Пример:

```json
{
  "admin": "admin"
}
```

**Важно:**

- TorrServer не разграничивает права пользователей
- У всех пользователей один и тот же Web UI и API
- Создавать более одного пользователя не обязательно

**Поведение скрипта:**

- При первом запуске создаётся пользователь (по умолчанию admin/admin)
- При повторном запуске скрипт меняет только первого пользователя
- Все дальнейшие изменения рекомендуется делать вручную

Подробная инструкция: [TorrServer_Authentication_accs.db.md](TorrServer_Authentication_accs.db.md)

### Безопасность

Если TorrServer используется только в локальной сети:

- можно использовать простой пароль
- либо вообще отключить авторизацию (не включено по умолчанию)

Сложные пароли имеют смысл только если доступ открывается извне.

## Требования

- **Linux-хост / NAS / VPS**
- **Архитектура:**
  - x86_64
  - ARM64 (Raspberry Pi и аналоги)
- **Установленные:**
  - Docker
  - Docker Compose
- **Доступ в интернет**
- **PrivateKey Cloudflare WARP**

## Получение wg0.conf (wgcf)

Общая логика (одинакова для всех ОС):

1. Установить wgcf
2. Зарегистрировать аккаунт
3. Сгенерировать профиль
4. Взять PrivateKey из wgcf-profile.conf

### Linux

```bash
wget -O wgcf https://github.com/ViRb3/wgcf/releases/download/v2.2.29/wgcf_2.2.29_linux_amd64
chmod +x wgcf
./wgcf register
./wgcf generate
cat wgcf-profile.conf
```

PrivateKey будет выглядеть так:

```
PrivateKey = xxxxxxxxxxxxxxxxxxxxx=
```

> **Обратите внимание** на символ `=`, он является частью ключа и важен.

### macOS

```bash
brew install wgcf
wgcf register
wgcf generate
cat wgcf-profile.conf
```

### Windows

1. Скачайте `wgcf_2.2.29_windows_amd64.exe` с [релизов GitHub](https://github.com/ViRb3/wgcf/releases). Обычно файл окажется в папке Downloads.
2. Откройте PowerShell и перейдите в папку (команды и имя файла можно добрать клавишей TAB):

```powershell
cd $HOME\Downloads
.\wgcf_2.2.29_windows_amd64.exe register
.\wgcf_2.2.29_windows_amd64.exe generate
cat wgcf-profile.conf
```

### Опционально, если есть Warp+ лицензия (для всех ОС)

```bash
wgcf license ВАШ_LICENSE_KEY
wgcf generate
```

## Использование скрипта

1. **Создать папку:**

```bash
mkdir torrserver
cd torrserver
```

2. **Скачать скрипт:**

```bash
wget https://raw.githubusercontent.com/0x800700/torrserverGluetun/main/install.sh
chmod +x install.sh
```

3. **Запустить:**

```bash
./install.sh
```

### После установки

- **Web UI:** `http://IP_СЕРВЕРА:8090`
- TorrServer доступен в локальной сети
- Весь внешний трафик идёт через VPN

## Лицензия

MIT License

## Контакты

Если у вас есть вопросы или предложения, создайте [Issue](https://github.com/0x800700/torrserverGluetun/issues) в репозитории.

---

⭐ Если проект оказался полезным, поставьте звезду на GitHub!
