# remna-chr

Автоматическая раскатка ноды [Remnawave](https://github.com/remnawave) на
RouterOS CHR поверх обычной VPS. Одна задача Ansible берёт свежую Ubuntu или
Debian, записывает на её диск образ CHR с включёнными контейнерами и доводит
его до готовой ноды: WARP, контейнеры Remnawave Node и Caddy, политика
маршрутизации по регионам и защитные списки адресов.

> **Операция разрушительная.** Системный диск VPS перезаписывается целиком,
> вернуть Ubuntu можно только переустановкой у провайдера. Запуск требует
> явного `confirm_dd=YES`.

## Как это устроено

Раскатка идёт в два строго разделённых этапа.

1. **Ubuntu → CHR.** Плейбук подключается к VPS по SSH, находит единственный
   диск с `/` и активный IPv4-маршрут, скачивает закреплённый образ CHR,
   сверяет SHA-256 и копирует образ в RAM: читать образ с того же диска, на
   который идёт запись, нельзя. В раздел образа встраивается индивидуальный
   `autorun.scr` с адресацией, учётными записями, защитой управления и REST
   HTTPS, после чего образ пишется на диск и машина перезагружается уже в CHR.
2. **Настройка через REST.** Плейбук ждёт REST API CHR и применяет остальное
   прямыми JSON-запросами: лицензию, WARP, сеть и образы контейнеров,
   Caddyfile, публикацию портов, address-list'ы, mangle, raw и scheduler'ы.

Подробная схема — в [`docs/bootstrap-design.md`](docs/bootstrap-design.md).

## Требования

**VPS.** Ubuntu или Debian, один диск с корневой файловой системой, IPv4 с
маршрутом по умолчанию, SSH под `root` или пользователем с `sudo`. Свободной
памяти — не меньше размера образа плюс 100 МБ (около 230 МБ), иначе плейбук
откажется писать диск.

**Управляющая машина** (или [Semaphore](https://semaphoreui.com/)):
`ansible-core`, Python 3 с модулем `bcrypt`, `ssh-keygen`, сетевой доступ к
VPS по SSH и затем к CHR по REST-порту. Внешние коллекции Ansible не нужны.

**Учётная запись MikroTik** — для активации лицензии CHR.

## Запуск

### Из командной строки

```
cp vars/deploy.example.yml vars/deploy.yml   # заполнить, затем:
ansible-vault encrypt vars/deploy.yml
ansible-playbook playbooks/deploy_chr.yml -e @vars/deploy.yml --ask-vault-pass
```

`vars/*.yml` игнорируется Git, в репозиторий попадает только пример.

### Через Semaphore

Шаблон типа **Ansible Playbook**: playbook `playbooks/deploy_chr.yml`,
inventory `inventory/controller.yml`. Параметры ниже передаются как Survey;
пароли и ключи — полями типа **Secret**. Key Store не нужен: SSH-доступ к VPS
тоже приходит из Survey.

## Параметры

| Переменная | По умолчанию | Назначение |
| --- | --- | --- |
| `confirm_dd` | `NO` | Строго `YES`, после проверки целевого IP. |
| `target_ipv4` | — | Публичный IPv4 VPS, диск которой будет заменён. |
| `target_ssh_user` | `root` | Пользователь SSH. |
| `target_ssh_password` | — | Пароль SSH; либо `target_ssh_private_key`. |
| `target_ssh_private_key` | — | Полный незашифрованный приватный ключ SSH. |
| `target_sudo_password` | — | Пароль `sudo`, если пользователь не `root`. |
| `routeros_admin_password` | — | Пароль `admin` в RouterOS. |
| `routeros_rest_user` | `ansible` | Пользователь REST API RouterOS. |
| `routeros_rest_password` | — | Его пароль. |
| `routeros_rest_port` | `8730` | HTTPS-порт REST; TCP/443 остаётся ноде. |
| `routeros_identity` | `chr-<IP>` | Common Name bootstrap-сертификата. |
| `controller_egress_cidr` | — | Публичный адрес управляющей машины, обычно `/32`. |
| `management_allow` | — | Дополнительные IPv4, CIDR или FQDN через запятую для доступа к управлению. |
| `mikrotik_account` | — | Логин MikroTik для лицензии. |
| `mikrotik_password` | — | Пароль MikroTik. |
| `chr_license_level` | `p-unlimited` | `free`, `p1`, `p10` или `p-unlimited`. |
| `node_region` | `EU` | `EU` или `RU`, см. ниже. |
| `node_domain` | — | Полное доменное имя ноды для Caddy. |
| `caddy_basicauth_user` | — | Логин Basic Auth заглушки Caddy. |
| `caddy_basicauth_password` | — | Её пароль, до 72 байт. |
| `remnanode_secret_key` | пусто | Секрет ноды Remnawave. |
| `fail_on_skipped_stages` | `true` | `false` — считать раскатку успешной, даже если этапы после поднятия CHR пропущены. |

Источники, которые можно заменить своими, — тоже переменные:

| Переменная | По умолчанию |
| --- | --- |
| `chr_image_repo`, `chr_release_tag`, `chr_asset_name`, `chr_asset_sha256` | образ RouterOS 7.24.4 из [`chr-container-rose`](https://github.com/Medium1992/chr-container-rose) |
| `ip_lists_base_url` | фрагменты address-list'ов из [`MikroTik_IPlist`](https://github.com/Medium1992/MikroTik_IPlist) |
| `remnanode_image` | `ghcr.io/medium1992/remnanode-ros` |
| `caddy_image` | `ghcr.io/medium1992/caddy-tblocker` |

## Что получается на CHR

- **Управление.** SSH, Winbox и REST HTTPS доступны только из `WhiteList`
  (управляющая машина и `management_allow`); telnet, FTP, HTTP, API, MAC-доступ,
  discovery и bandwidth-test выключены, IPv6 отключён. Источник, похожий на
  сканирование портов, попадает в `PortScanners` на сутки и отбрасывается в
  `raw`.
- **WARP.** Интерфейс `wg-warp`, регистрация ключа у Cloudflare, peer, адрес,
  NAT и отдельная таблица маршрутизации. Если регистрация не прошла, peer и
  адрес всё равно создаются со стандартными значениями Cloudflare и
  комментарием `warp-auto UNREGISTERED` — остаётся подставить свои ключи.
- **Контейнеры.** Bridge `Remna` (`192.168.243.0/28`), veth-интерфейсы,
  Caddyfile, DNS для контейнеров, dst-nat на 443 и ограниченный `WhiteList`
  порт 563, образы Remnawave Node и Caddy. Оба контейнера создаются в
  привилегированном режиме (`privileged=yes`, RouterOS 7.24+). Контейнеры
  скачиваются, но намеренно не запускаются: запуск — отдельное осознанное
  действие.
- **Регион.** На `EU` через WARP уходят российские адреса, Cloudflare и
  сервисы определения геолокации по IP; на `RU` — весь трафик контейнеров,
  кроме DNS и `WhiteList`. Политика касается только трафика контейнеров;
  собственный трафик роутера идёт напрямую.
- **Блокировки** в `raw` для трафика контейнеров: Skipa, CINS Army, Spamhaus
  DROP, все запущенные релеи Tor, SMTP, мессенджер MAX и подсеть
  `130.49.152.0/24` (список `Telega`). Abuse-списки и Tor
  обновляются парами `основной/_NEXT`, чтобы блокировка не проседала на время
  загрузки. Мосты Tor (obfs4, webtunnel, snowflake) списком закрыть нельзя в
  принципе.
- **Расписание.** `ADDRESS_LISTS` раз в сутки, `TOR_NODES` раз в 6 часов,
  `ABUSE_LISTS_ON_BOOT` при каждой загрузке — динамические списки после
  перезагрузки не сохраняются.

## Поведение при ошибках

До момента, когда CHR ответил по REST, плейбук падает на первой же ошибке:
проверки ввода, запись диска и ожидание REST — это точки, после которых
продолжать бессмысленно или опасно.

После этого раскатка идёт до конца. Каждый этап обёрнут в `block`/`rescue`:
упавший этап записывается в `deploy_failures`, в лог выводится строка
`SKIPPED STAGE '<этап>' at task '<задача>': <ошибка>`, и плейбук переходит к
следующему. В конце задача `Report the CHR deployment result` печатает список
пропущенного и помечает запуск как failed; принять такой результат можно с
`fail_on_skipped_stages=false`.

Раскатка рассчитана на один проход по свежей VPS. Повторный запуск по уже
поднятому CHR не предусмотрен: почти все REST-вызовы создают объекты и
упадут на дубликатах. Упавший этап проще довести вручную по логу.

## Смена версии RouterOS

Образ закреплён тегом, именем файла и SHA-256 (`chr_release_tag`,
`chr_asset_name`, `chr_asset_sha256` в `playbooks/deploy_chr.yml`). Для
перехода на другую версию достаточно подставить значения из описания нужного
релиза `chr-container-rose`. Подменённый или пересобранный образ не пройдёт
сверку и будет отвергнут до записи на диск.

## Лицензия

[GNU AGPL-3.0](LICENSE). Пользоваться, изучать и менять можно свободно. Но
если вы распространяете изменённую версию или предоставляете её как сервис,
исходный код изменений нужно открыть под той же лицензией: закрытых форков
этой раскатки быть не должно.

RouterOS — продукт MikroTik, Remnawave — самостоятельный проект; этот
репозиторий ни с одним из них не связан.
