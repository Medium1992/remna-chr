# Схема раскатки CHR

Образ CHR: пакеты `container` и `rose-storage`, `device-mode` `advanced` с
`container=yes` и `traffic-gen=yes`, пустая конфигурация. По умолчанию —
релиз RouterOS 7.24.4 из
[`chr-container-rose`](https://github.com/Medium1992/chr-container-rose)
(переменные `chr_image_repo`, `chr_release_tag`, `chr_asset_name`,
`chr_asset_sha256`). Образ загружается по прямой ссылке на ассет релиза и
сверяется с `chr_asset_sha256`. Адреса VPS, учётные данные и конфигурация в
образе отсутствуют.

Раскатка выполняется в два этапа.

## 1. Ubuntu → CHR и `autorun.scr`

`deploy_chr.yml` подключается к VPS по SSH и определяет единственный диск с
`/` и параметры активного IPv4-маршрута. Образ загружается на диск VPS,
сверяется по SHA-256 и копируется в tmpfs; `dd` читает образ из tmpfs, а не с
перезаписываемого диска.

В раздел `rw` образа записывается `autorun.scr`, сформированный под VPS:

1. Интерфейс CHR определяется по MAC активного интерфейса Ubuntu; на него
   назначаются IPv4-адрес, маршрут по умолчанию и шлюз. При адресации `/32`
   параметром `network` служит адрес шлюза.
2. Удаляется DHCP-клиент; задаются DNS, NTP, часовой пояс UTC; IPv6
   отключается.
3. Создаётся пользователь REST, задаётся пароль `admin`; выключаются
   telnet, ftp, www, api, api-ssl и reverse-proxy; включается `www-ssl` с
   самоподписанным сертификатом на порту `routeros_rest_port`.
4. Создаются interface list `WAN`, address-list `WhiteList`, правила
   `input`/`forward` и source NAT; MAC-server, neighbor discovery и
   bandwidth-server отключаются.
5. Правило PSD `21,3s,3,1` в `input` добавляет источник в `PortScanners` на
   один день; правило `raw prerouting` отбрасывает трафик с источником из
   `PortScanners`. Исключения для `WhiteList` нет. На втором этапе правила
   DNS для bridge `Remna` добавляются перед PSD, PSD остаётся предпоследним
   правилом `input`.

Последовательность записи: SysRq emergency remount, пауза,
`dd bs=1024 conv=fsync`, пауза, SysRq sync, пауза, SysRq reboot.

## 2. Настройка через RouterOS REST HTTPS

После перезагрузки выполняется ожидание `https://<IP>:<routeros_rest_port>/rest`
с проверкой сертификата выключенной; доступ к порту ограничен `WhiteList`.

Объекты, создаваемые JSON-запросами REST:

- WARP: WireGuard-интерфейс `wg-warp`, регистрация ключа в API Cloudflare,
  peer, адрес, NAT, таблица и маршрут `wg-warp`, `wg-warp` в `WAN`;
- bridge `Remna`, veth-интерфейсы `caddy`, `remna-node`, `veth-warp`,
  каталоги, Caddyfile, envs/mounts, контейнеры `remna-node` (интерфейсы
  `remna-node` и `veth-warp`) и `caddy` (`remnanode_image`, `caddy_image`) с
  `privileged=yes`, без запуска;
- dst-nat TCP/443 и TCP/563, для 563 — только из `WhiteList`;
- правила mangle, raw и address-list'ы `DNS`, `MAX`, `Telega`. Порядок
  mangle `prerouting`: `retain established`, `accept WAN`, mark-routing для
  установленных соединений с меткой `WARP`, исключения `WhiteList` и `DNS`,
  `accept Caddy`, маркировка соединений с `veth-warp`, региональная
  маркировка, mark-routing для новых соединений с меткой `WARP`;
- scheduler'ы `ADDRESS_LISTS` (раз в сутки), `TOR_NODES` (раз в 6 часов) и
  `ABUSE_LISTS_ON_BOOT` (при загрузке).

Имя WAN-интерфейса для dst-nat определяется по MAC исходного интерфейса
Ubuntu через `/interface/ethernet`; при отсутствии совпадения используется
`ether1` и этап отмечается как пропущенный. Учётные данные MikroTik для
`/system license renew` передаются в скрипт в Base64 и декодируются
`:convert`.

При ошибке регистрации в API Cloudflare peer и адрес WARP создаются со
стандартными значениями: публичный ключ peer'а и endpoint общие для всех
клиентов WARP, клиентский адрес — `172.16.0.2`. Эти записи получают
комментарий `warp-auto UNREGISTERED`.

До ответа REST API ошибки прерывают выполнение. После — каждый этап выполняется
в `block`/`rescue`: ошибка записывается в `deploy_failures` и в лог,
выполнение продолжается, итоговая задача выводит список пропущенных этапов и
завершает запуск со статусом failed (кроме `fail_on_skipped_stages=false`).
Учётные данные REST заданы через `module_defaults` для `ansible.builtin.uri`;
`no_log` установлен на задачах, в запросе или ответе которых есть секреты.
Запрос к API Cloudflare переопределяет `module_defaults` без учётных данных
REST.

## Загрузка address-list'ов

Загрузчики address-list'ов — system script'ы RouterOS. `ADDRESS_LISTS`
запускает их последовательно: все используют глобальную переменную
`AddressList`. `ABUSE_CINS`, `ABUSE_SPAMHAUS` и `TOR_NODES` загружают данные
в меньший из пары списков `<имя>` / `<имя>_NEXT`, сверяют количество записей с
manifest и после этого очищают второй список; raw-правила для обоих списков
постоянные. Записи этих списков динамические, `ABUSE_LISTS_ON_BOOT`
загружает их через 20 секунд после старта CHR.

`TOR_NODES` запускается собственным scheduler'ом раз в 6 часов с 03:40 UTC,
вне цепочки `ADDRESS_LISTS`, и пропускает запуск, если выполняется
`ADDRESS_LISTS`.

## Входные параметры

- IPv4 VPS и доступ SSH: пароль или приватный ключ; для пользователя,
  отличного от `root`, — `sudo`.
- `controller_egress_cidr`: IPv4 CIDR управляющей машины.
- `management_allow`: IPv4, CIDR и FQDN через запятую для `WhiteList`; IP
  добавляются раньше FQDN.
- Пароли RouterOS, Basic Auth для Caddyfile, учётная запись MikroTik.
- `confirm_dd=YES`.
