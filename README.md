# remna-chr

Ansible-плейбук: установка RouterOS CHR на VPS с Ubuntu или Debian и
последующая настройка через REST API — WireGuard-туннель Cloudflare WARP,
контейнеры Remnawave Node и Caddy, policy routing, address-list'ы и правила
firewall.

Системный диск VPS перезаписывается образом CHR полностью. Запуск требует
параметра `confirm_dd=YES`.

## Этапы

1. **Ubuntu → CHR.** Подключение к VPS по SSH, определение единственного диска
   с `/` и активного IPv4-маршрута, загрузка закреплённого образа CHR, сверка
   SHA-256, копирование образа в tmpfs. В раздел образа записывается
   `autorun.scr` с адресацией, учётными записями, правилами firewall и REST
   HTTPS. Образ записывается на диск, VPS перезагружается в CHR.
2. **Настройка через REST.** Ожидание REST API CHR, затем JSON-запросы:
   лицензия, WARP, сеть и образы контейнеров, Caddyfile, dst-nat,
   address-list'ы, mangle, raw, scheduler'ы.

Подробно — в [`docs/bootstrap-design.md`](docs/bootstrap-design.md).

## Требования

**VPS:** Ubuntu или Debian, один диск с корневой файловой системой, IPv4 с
маршрутом по умолчанию, SSH под `root` или пользователем с `sudo`, свободная
память не меньше размера образа плюс 100 МБ (около 230 МБ).

**Управляющая машина** или [Semaphore](https://semaphoreui.com/):
`ansible-core`, Python 3 с модулем `bcrypt`, `ssh-keygen`, доступ к VPS по SSH
и к CHR по REST-порту. Внешние коллекции Ansible не используются.

**Учётная запись MikroTik** для `/system license renew`.

## Запуск

### Командная строка

```
cp vars/deploy.example.yml vars/deploy.yml
ansible-vault encrypt vars/deploy.yml
ansible-playbook playbooks/deploy_chr.yml -e @vars/deploy.yml --ask-vault-pass
```

`vars/*.yml`, кроме примера, исключён из Git.

### Semaphore

Шаблон типа **Ansible Playbook**: playbook `playbooks/deploy_chr.yml`,
inventory `inventory/controller.yml`. Параметры передаются через Survey,
пароли и ключи — полями типа **Secret**. Key Store не требуется.

## Параметры

| Переменная | По умолчанию | Описание |
| --- | --- | --- |
| `confirm_dd` | `NO` | `YES` разрешает запись образа на диск. |
| `target_ipv4` | — | Публичный IPv4 VPS. |
| `target_ssh_user` | `root` | Пользователь SSH. |
| `target_ssh_password` | — | Пароль SSH; альтернатива — `target_ssh_private_key`. |
| `target_ssh_private_key` | — | Незашифрованный приватный ключ SSH целиком. |
| `target_sudo_password` | — | Пароль `sudo` для пользователя, отличного от `root`. |
| `routeros_admin_password` | — | Пароль пользователя `admin`. |
| `routeros_rest_user` | `ansible` | Пользователь REST API. |
| `routeros_rest_password` | — | Пароль пользователя REST API. |
| `routeros_rest_port` | `8730` | Порт `www-ssl`. |
| `routeros_identity` | `chr-<IP>` | Common Name сертификата `www-ssl`. |
| `controller_egress_cidr` | — | Публичный адрес управляющей машины, обычно `/32`. |
| `management_allow` | — | IPv4, CIDR или FQDN через запятую, добавляемые в `WhiteList`. |
| `mikrotik_account` | — | Учётная запись MikroTik. |
| `mikrotik_password` | — | Пароль учётной записи MikroTik. |
| `chr_license_level` | `p-unlimited` | `free`, `p1`, `p10` или `p-unlimited`. |
| `node_region` | `EU` | `EU` или `RU`, определяет набор правил mangle. |
| `node_domain` | — | FQDN для Caddyfile. |
| `caddy_basicauth_user` | — | Пользователь Basic Auth в Caddyfile. |
| `caddy_basicauth_password` | — | Пароль Basic Auth, до 72 байт. |
| `remnanode_secret_key` | пусто | Значение переменной окружения `SECRET_KEY` контейнера Remnawave Node. |
| `fail_on_skipped_stages` | `true` | `false` — итоговый статус успешный при пропущенных этапах второго этапа. |

Источники:

| Переменная | По умолчанию |
| --- | --- |
| `chr_image_repo`, `chr_release_tag`, `chr_asset_name`, `chr_asset_sha256` | RouterOS 7.24.4 из [`chr-container-rose`](https://github.com/Medium1992/chr-container-rose) |
| `ip_lists_base_url` | фрагменты address-list'ов из [`MikroTik_IPlist`](https://github.com/Medium1992/MikroTik_IPlist) |
| `remnanode_image` | `ghcr.io/medium1992/remnanode-ros` |
| `caddy_image` | `ghcr.io/medium1992/caddy-tblocker` |

## Конфигурация CHR

- **Сервисы.** SSH, Winbox и `www-ssl` принимают подключения только из
  address-list'а `WhiteList`. Выключены telnet, ftp, www, api, api-ssl,
  reverse-proxy, MAC-server, neighbor discovery, bandwidth-server; IPv6
  отключён. Правило PSD
  в `input` добавляет источник в `PortScanners` на сутки, правило `raw`
  отбрасывает трафик из `PortScanners`.
- **WARP.** Интерфейс `wg-warp`, регистрация публичного ключа в API Cloudflare,
  peer, адрес, NAT и таблица маршрутизации `wg-warp`. При ошибке регистрации
  peer и адрес создаются со стандартными значениями Cloudflare и комментарием
  `warp-auto UNREGISTERED`.
- **Контейнеры.** Bridge `Remna` (`192.168.243.0/28`), veth-интерфейсы,
  Caddyfile, правила DNS для bridge, dst-nat TCP/443 и TCP/563 (для 563 —
  только из `WhiteList`), контейнеры `remna-node` и `caddy` с
  `privileged=yes` (RouterOS 7.24+). Контейнеры создаются и загружаются без
  запуска.
- **Policy routing** для трафика с bridge `Remna`: при `node_region=EU` в
  таблицу `wg-warp` маркируются соединения к `LIST_RU`, `CLOUDFLARE` и
  `GEO_IP_DETECT`; при `node_region=RU` — все соединения, кроме адресов из
  `DNS` и `WhiteList`. Не маркируются трафик контейнера `caddy`
  (`192.168.243.2`) и трафик самого CHR.
- **Raw drop.** Для всего трафика: источник или назначение в `SKIPA_CIDR`,
  назначение в `MAX` и `Telega`, TCP-порты 25, 465, 587. Для трафика с bridge
  `Remna`: назначение в `ABUSE_CINS`, `ABUSE_SPAMHAUS`, `TOR_NODES`. Эти три
  списка обновляются парами `<имя>` и `<имя>_NEXT`, у каждого из пары своё
  постоянное правило.
- **Scheduler'ы:** `ADDRESS_LISTS` раз в сутки, `TOR_NODES` раз в 6 часов,
  `ABUSE_LISTS_ON_BOOT` при каждой загрузке — записи списков динамические.

## Обработка ошибок

До ответа REST API любая ошибка останавливает выполнение. После — каждый этап
находится в `block`/`rescue`: ошибка записывается в `deploy_failures`, в лог
выводится `SKIPPED STAGE '<этап>' at task '<задача>': <ошибка>`, выполнение
продолжается со следующего этапа. Задача `Report the CHR deployment result`
выводит список пропущенных этапов и завершает запуск со статусом failed, если
не задан `fail_on_skipped_stages=false`.

Плейбук выполняется один раз на VPS с Ubuntu или Debian. Повторный запуск на
уже установленном CHR не поддерживается: REST-запросы создают объекты и
завершаются ошибкой на существующих.

## Версия RouterOS

Образ определяется переменными `chr_release_tag`, `chr_asset_name` и
`chr_asset_sha256` в `playbooks/deploy_chr.yml`. Для другой версии
подставляются значения из соответствующего релиза `chr-container-rose`. При
несовпадении SHA-256 выполнение останавливается до записи на диск.

## Лицензия

[GNU AGPL-3.0](LICENSE).

RouterOS — продукт MikroTik, Remnawave — отдельный проект; репозиторий с ними
не связан.
