# docker-dev

Локальная среда для PHP/Laravel-проектов на Docker. Один Traefik принимает HTTPS и раздаёт его по доменам, у каждого проекта свои PHP, nginx, PostgreSQL, Redis, очередь и Node.

Работает на macOS и Linux.

## Быстрый старт

Нужны Docker, `mkcert` и `make`.

```bash
cp .env.local.example .env.local   # заполнить Git и пути к SSH-ключам
make up                            # сертификаты + Traefik
make project name=blog             # создать проект, скрипт задаст вопросы
cd projects/blog.prj.loc && make up
```

Проект откроется на `https://blog.prj.loc`. Подставьте в `make project` своё имя вместо `blog`.

## Домены

У каждой машины один домен, он хранится в `DEV_DOMAIN` в `.env.local`. По умолчанию это `prj.loc`.

| Где | Домен | Проект | Traefik |
| --- | --- | --- | --- |
| Mac, локально | `prj.loc` | `blog.prj.loc` | `traefik.loc` |
| Сервер dell-srv | `srv.loc` | `blog.srv.loc` | `traefik.srv.loc` |

Сменить домен:

```bash
make domain name=srv.loc
```

Команда сама обновит `.env.local`, перевыпустит сертификат и перезапустит Traefik. Вспоминать про сертификат не нужно: `make up` и `make project` тоже проверяют его и перевыпускают, если он не подходит к домену или истекает меньше чем через 30 дней.

Домен записывается в файлы проекта при создании. Уже созданные проекты остаются на старом домене, `make domain` покажет их списком.

## Доступ к серверу с Mac

Проекты на сервере открываются через Tailscale, и дома, и снаружи. Локальные `*.prj.loc` при этом работают как обычно.

Настройка нужна один раз.

**1. Сервер.** Выполнить `make domain name=srv.loc`. На Linux с Tailscale и доменом не `prj.loc` автоматически запустится DNS-контейнер `dev-dns`. Он отвечает на `*.srv.loc` адресом сервера и слушает только интерфейс `tailscale0`.

**2. Tailscale.** В [админке](https://login.tailscale.com/admin/dns): Nameservers → Add nameserver → Custom:
- Nameserver: Tailscale-IP сервера (`tailscale ip -4` на сервере)
- Включить Restrict to domain: `srv.loc`

**3. Каждый Mac.** Сделать сертификаты сервера доверенными. Копируется только публичный `rootCA.pem`:

```bash
mkdir -p ~/dell-srv-ca
scp alexmihel@dell-srv:.local/share/mkcert/rootCA.pem ~/dell-srv-ca/
CAROOT=~/dell-srv-ca mkcert -install
```

Файл `rootCA-key.pem` никогда не копируйте: с ним можно выпустить доверенный сертификат на любой сайт.

**4. Проверка.** Открыть `https://whoami.srv.loc`.

Если имя не резолвится: в Tailscale на Mac должен быть включён Use Tailscale DNS, а в браузере выключен Secure DNS с собственным провайдером.

## Команды

В корне репозитория:

| Команда | Что делает |
| --- | --- |
| `make up` | Приводит сертификаты, DNS и Traefik в соответствие с `DEV_DOMAIN` |
| `make domain name=...` | Меняет домен машины |
| `make project name=...` | Создаёт проект |
| `make certs` | Перевыпускает сертификат принудительно |

В папке проекта, `projects/<имя>.<домен>/`:

| Команда | Что делает |
| --- | --- |
| `make up` / `down` / `restart` | Запуск и остановка контейнеров |
| `make build` | Пересборка образов |
| `make shell` | Консоль в PHP-контейнере |
| `make artisan cmd="..."` | Команда artisan |
| `make composer cmd="..."` | Команда composer |
| `make migrate` / `seed` / `fresh` | Работа со схемой БД |
| `make db-dump` / `db-restore file=...` | Дамп и восстановление БД |
| `make test` | Тесты |
| `make npm-install` / `npm-dev` / `npm-build` | Фронтенд |
| `make logs` | Логи |

Полный список в `Makefile` проекта.

## Как устроено

```
docker-dev/
├── .env.local        личные настройки и DEV_DOMAIN, не в git
├── scripts/          создание проектов, домен, сертификаты
├── template/         шаблоны файлов проекта
├── shared/           сертификаты и шаблон nginx
├── traefik/          Traefik, whoami и DNS-контейнер
└── projects/         проекты, не в git
```

- `traefik/.env` генерируется при `make up`, править его вручную не нужно.
- PostgreSQL каждого проекта доступен с хоста на своём порту, начиная с `5433`. Порт показывается при создании проекта и записан в его `docker-compose.yml`. С Mac: `dell-srv:5433`.

## Особенности Linux

- Контейнеры работают под UID/GID пользователя хоста, иначе файлы в проекте станут принадлежать root.
- Версия Traefik не ниже v3.6: старые версии не работают с API Docker 29.
- Xdebug запускается по триггеру. На сервере `host.docker.internal` не резолвится, поэтому для отладки из IDE на Mac в `xdebug.client_host` нужно указать его Tailscale-IP.
- Vite dev-сервер (порт 5173) наружу не проброшен, для HMR на сервере нужен отдельный маршрут в Traefik.
