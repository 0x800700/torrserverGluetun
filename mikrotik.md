# Настройка доступа к TorrServer через MikroTik

## Описание

Данная инструкция описывает, как настроить доступ к TorrServer через роутер MikroTik с использованием проброса портов (DNAT) и ограничением доступа по IP-адресам.

**Что это даёт:**
- Доступ к TorrServer из интернета (через внешний IP провайдера)
- Контроль доступа: только разрешённые IP-адреса могут подключиться
- Безопасность: все остальные запросы блокируются
- Удобное управление списком разрешённых IP
- Возможность выдавать временный доступ

**Схема подключения:**
```
Интернет → Внешний IP провайдера:8090 → MikroTik (DNAT) → Локальный сервер с TorrServer:8090
```

---

## ⚠️ ВАЖНО: Безопасность при работе с терминалом MikroTik

**КРИТИЧНО:** MikroTik выполняет команды **сразу после вставки**, без нажатия Enter!

### Правильный порядок действий:

1. **Сначала** откройте команды в текстовом редакторе (Notepad++, VS Code, Блокнот)
2. **Замените** все placeholder-значения на ваши реальные IP-адреса:
   - `IP_провайдера` — внешний IP-адрес от провайдера
   - `IP_сервера_с_torrserver` — локальный IP вашего сервера (например, 192.168.88.250)
   - `x1x.XxX.xXx.XxX` — IP-адрес, которому разрешён доступ
3. **Только после этого** копируйте и вставляйте команды в терминал MikroTik

### Пример замены:

**Было:**
```
dst-address=IP_провайдера
to-addresses=IP_сервера_с_torrserver
```

**Стало:**
```
dst-address=203.0.113.45
to-addresses=192.168.88.250
```

---

## Шаг 1. Создание списка разрешённых IP-адресов (Address List)

Address List — это именованный список IP-адресов, который можно использовать в правилах firewall.

### Добавление первого разрешённого IP

```bash
/ip firewall address-list
add list=torrserver_allowed address=x1x.XxX.xXx.XxX comment="Home access"
```

**Где:**
- `list=torrserver_allowed` — имя списка (можно назвать как угодно)
- `address=x1x.XxX.xXx.XxX` — IP-адрес, которому разрешён доступ
- `comment="Home access"` — комментарий для удобства

### Добавление нескольких IP-адресов

Если нужно разрешить доступ нескольким адресам:

```bash
/ip firewall address-list
add list=torrserver_allowed address=x2x.XxX.xXx.XxX comment="Friend"
add list=torrserver_allowed address=x3x.XxX.xXx.XxX comment="Office"
add list=torrserver_allowed address=x4x.XxX.xXx.XxX comment="Mobile network"
```

---

## Шаг 2. Настройка DNAT (проброс порта)

DNAT (Destination NAT) перенаправляет входящие запросы с внешнего IP на внутренний сервер.

```bash
/ip firewall nat
add chain=dstnat \
    protocol=tcp \
    dst-address=IP_провайдера \
    dst-port=8090 \
    action=dst-nat \
    to-addresses=IP_сервера_с_torrserver \
    to-ports=8090 \
    comment="TorrServer WebUI/API"
```

**Где:**
- `dst-address=IP_провайдера` — ваш внешний IP от провайдера (например, 203.0.113.45)
- `dst-port=8090` — порт, на который будут приходить запросы извне
- `to-addresses=IP_сервера_с_torrserver` — локальный IP сервера с TorrServer (например, 192.168.88.250)
- `to-ports=8090` — порт TorrServer на локальном сервере

**Важно:** Если у вас динамический IP от провайдера, используйте DynDNS и правило с `dst-address-type=local`.

---

## Шаг 3. Настройка Firewall Filter (обязательно!)

Без правил фильтрации DNAT откроет доступ всем. Нужно явно разрешить только нужные IP.

### Правило 1: Разрешаем доступ с разрешённых IP

```bash
/ip firewall filter
add chain=forward \
    protocol=tcp \
    src-address-list=torrserver_allowed \
    dst-address=IP_сервера_с_torrserver \
    dst-port=8090 \
    action=accept \
    comment="Allow TorrServer from allowed IPs"
```

**Где:**
- `chain=forward` — цепочка для транзитного трафика (из интернета в локальную сеть)
- `src-address-list=torrserver_allowed` — источник должен быть в нашем списке
- `dst-address=IP_сервера_с_torrserver` — назначение — наш сервер
- `action=accept` — разрешить

### Правило 2: Блокируем все остальные подключения

```bash
/ip firewall filter
add chain=forward \
    protocol=tcp \
    dst-address=IP_сервера_с_torrserver \
    dst-port=8090 \
    action=drop \
    comment="Drop TorrServer from all other IPs"
```

**Где:**
- `action=drop` — отклонить все остальные подключения к порту 8090

---

## Управление доступом

### Добавить новый IP-адрес

```bash
/ip firewall address-list add list=torrserver_allowed address=1.2.3.4 comment="New user"
```

### Удалить IP-адрес из списка

```bash
/ip firewall address-list remove [find list=torrserver_allowed address=1.2.3.4]
```

### Посмотреть список всех разрешённых IP

```bash
/ip firewall address-list print where list=torrserver_allowed
```

Вывод будет таким:
```
Flags: X - disabled, D - dynamic
 #   LIST                 ADDRESS         
 0   torrserver_allowed   203.0.113.10    Home access
 1   torrserver_allowed   198.51.100.25   Friend
 2   torrserver_allowed   192.0.2.50      Office
```

### Временно отключить IP (не удаляя)

```bash
/ip firewall address-list disable [find list=torrserver_allowed address=1.2.3.4]
```

### Включить обратно

```bash
/ip firewall address-list enable [find list=torrserver_allowed address=1.2.3.4]
```

---

## Бонус: Временный доступ

Очень полезная функция для гостей или временного доступа.

### Выдать доступ на 1 час

```bash
/ip firewall address-list
add list=torrserver_allowed address=1.2.3.4 timeout=1h comment="Temporary guest access"
```

### Другие примеры timeout

```bash
# На 30 минут
add list=torrserver_allowed address=1.2.3.4 timeout=30m

# На 1 день
add list=torrserver_allowed address=1.2.3.4 timeout=1d

# На 1 неделю
add list=torrserver_allowed address=1.2.3.4 timeout=7d
```

MikroTik автоматически удалит IP из списка по истечении времени.

---

## Проверка настроек

### 1. Проверить NAT

```bash
/ip firewall nat print
```

Должно быть правило с `chain=dstnat` и `action=dst-nat`.

### 2. Проверить Filter

```bash
/ip firewall filter print
```

Должно быть два правила:
- `action=accept` для разрешённых IP
- `action=drop` для всех остальных

### 3. Проверить Address List

```bash
/ip firewall address-list print where list=torrserver_allowed
```

---

## Тестирование

### С разрешённого IP-адреса

Откройте браузер и перейдите:
```
http://IP_провайдера:8090
```

Должен открыться Web UI TorrServer.

### С неразрешённого IP-адреса

Попытка подключения должна быть заблокирована (timeout или connection refused).

---

## Troubleshooting

### Не открывается TorrServer извне

1. **Проверьте, что TorrServer запущен:**
   ```bash
   docker ps
   ```

2. **Проверьте, что порт 8090 открыт локально:**
   ```bash
   curl http://IP_сервера_с_torrserver:8090
   ```

3. **Проверьте правила NAT на MikroTik:**
   ```bash
   /ip firewall nat print
   ```

4. **Проверьте правила Filter:**
   ```bash
   /ip firewall filter print
   ```

5. **Проверьте, что ваш IP в списке:**
   ```bash
   /ip firewall address-list print where list=torrserver_allowed
   ```

### Доступ есть у всех (небезопасно!)

Проверьте порядок правил Filter:
```bash
/ip firewall filter print
```

Правило `accept` должно быть **выше** правила `drop`. Если нет, переместите:
```bash
/ip firewall filter move [find comment="Allow TorrServer from allowed IPs"] destination=0
```

---

## Безопасность

### Рекомендации

1. **Не используйте простые пароли** для TorrServer (admin/admin) при открытии доступа извне
2. **Регулярно проверяйте** список разрешённых IP
3. **Включите логирование** попыток подключения:

```bash
/ip firewall filter
add chain=forward \
    protocol=tcp \
    dst-address=IP_сервера_с_torrserver \
    dst-port=8090 \
    action=log \
    log-prefix="TorrServer blocked" \
    place-before=[find comment="Drop TorrServer from all other IPs"]
```

Логи можно посмотреть:
```bash
/log print where message~"TorrServer"
```

---

## Дополнительные возможности

### Ограничение по подсети

Если нужно разрешить доступ целой подсети:

```bash
/ip firewall address-list
add list=torrserver_allowed address=192.168.1.0/24 comment="Home network"
```

### Ограничение по времени суток

Можно ограничить доступ только определёнными часами:

```bash
/ip firewall filter
add chain=forward \
    protocol=tcp \
    src-address-list=torrserver_allowed \
    dst-address=IP_сервера_с_torrserver \
    dst-port=8090 \
    time=8h-23h,mon,tue,wed,thu,fri \
    action=accept \
    comment="Allow TorrServer 8:00-23:00 weekdays only"
```

---

## Полезные команды для мониторинга

### Посмотреть активные подключения к TorrServer

```bash
/ip firewall connection print where dst-port=8090
```

### Посмотреть статистику по правилам

```bash
/ip firewall filter print stats
```

### Экспорт конфигурации

Сохранить все настройки в файл:

```bash
/export file=torrserver-config
```

Файл будет сохранён в `/files/` на MikroTik.

---

## Связанные документы

- [TorrServer + Gluetun README](README.md)
- [TorrServer Authentication Guide](TorrServer_Authentication_accs.db.md)

---


---

⚠️ **Помните:** Проброс портов в интернет всегда несёт риски. Используйте сильные пароли и регулярно обновляйте список разрешённых IP-адресов.
