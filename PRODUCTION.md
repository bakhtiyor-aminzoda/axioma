# 🚀 Axioma CRM — Production Operations Manual & Architecture

> **Axioma CRM** — Единая система коммуникаций и воронки продаж для бизнеса Таджикистана.
> Все сообщения (WhatsApp, Instagram, Telegram, Web chat) в одном рабочем пространстве для ваших операторов.

---

## 🏛 1. Архитектура MVP (Single-Node VPS)

Рекомендованная конфигурация для первого коммерческого этапа (10–50 бизнесов, 50–200 операторов):
* **Сервер:** 1 VPS (Ubuntu 22.04 / 24.04 LTS)
* **Характеристики:** 4 vCPU, 8 GB RAM, **80 GB NVMe SSD** (Hetzner, DigitalOcean или локальный ЦОД в ТЧ). 80 GB дают необходимый запас для Docker-образов, логов, WAL PostgreSQL, временных файлов и хранения предыдущих rollback-образов.
* **Сеть & Порты:** 80 (HTTP), 443 (HTTPS), 22 (SSH). Порты PostgreSQL (5432) и Redis (6379) строго закрыты внутри изолированной Docker-сети.

```
                  ┌──────────────────────────────────────────────┐
                  │              Internet / Clients              │
                  └───────┬──────────────────────────────┬───────┘
                          │ (HTTPS 443)                  │ (HTTPS 443)
                          ▼                              ▼
                  ┌───────────────┐              ┌───────────────┐
                  │ crm.axioma.tj │              │ api.axioma.tj │
                  └───────┬───────┘              └───────┬───────┘
                          │                              │
                          ▼                              ▼
                  ┌──────────────────────────────────────────────┐
                  │           Nginx Reverse Proxy & SSL          │
                  └───────┬──────────────────────────────┬───────┘
                          │                              │
            (HTTP 3000 + WebSocket)              (HTTP 8080)
                          │                              │
                          ▼                              ▼
        ┌───────────────────────────────────┐    ┌─────────────────────┐
        │       axioma_web (Rails + Vue 3)  │    │ evolution_api       │
        │       Axioma CRM Web Engine       │◄───┤ WhatsApp Gateway    │
        └──────────────┬────────────────────┘    └──────────┬──────────┘
                       │                                    │
                       ▼                                    │
        ┌───────────────────────────────────┐               │
        │       axioma_sidekiq              │               │
        │       Background Worker Jobs      │               │
        └──────────────┬────────────────────┘               │
                       │                                    │
                       ▼                                    │
        ┌───────────────────────────────────┐               │
        │       axioma_postgres (PG 16)     │◄──────────────┘
        │       + pgvector                  │
        │       Multi-Tenant Data Store     │
        └───────────────────────────────────┘
                       │
                       ▼
        ┌───────────────────────────────────┐
        │       axioma_redis (Redis 7)      │
        │       Cache & Message Broker      │
        └───────────────────────────────────┘
```

---

## 📦 2. Используемые Docker-образы и версионирование

| Сервис | Образ | Версионирование | Назначение |
| :--- | :--- | :--- | :--- |
| **Axioma Web & Sidekiq** | `ghcr.io/bakhtiyor-aminzoda/axioma:${AXIOMA_IMAGE_TAG}` | **Immutable Tag** (`v0.1.0` или git SHA) | CRM интерфейс, API, ActionCable, Sidekiq |
| **PostgreSQL** | `pgvector/pgvector:pg16` | Фиксированная версия `pg16` | Мультитенантная база данных |
| **Redis** | `redis:7-alpine` | `7-alpine` | Кэш, брокер сообщений, очереди |
| **Evolution API** | `evoapicloud/evolution-api:latest` | `latest` (или pinned hash) | Шлюз WhatsApp (QR-код и Baileys) |
| **Reverse Proxy** | Nginx на хосте | Ubuntu LTS pkg | SSL, HTTP/2, WebSocket proxy |

> [!IMPORTANT]
> **Никогда не используйте тег `:latest` на production-сервере.**
> Если запустить `docker compose pull` с тегом `:latest`, сервер неконтролируемо обновится на последнюю сборку, что при наличии регрессий приведет к остановке сервиса у всех клиентов.
> Всегда указывайте фиксированный релизный тег в `.env`, например: `AXIOMA_IMAGE_TAG=v0.1.0`.

---

## 🔗 3. Фактические production-эндпоинты вебхуков и интеграций

Для исключения расхождений при настройке каналов зафиксированы точные маршруты из `config/routes.rb`:

| Канал | Метод и реальный маршрут (Axioma / Chatwoot) | Описание |
| :--- | :--- | :--- |
| **WhatsApp Cloud API (Meta)** | `GET /webhooks/whatsapp/:phone_number`<br>`POST /webhooks/whatsapp/:phone_number` | Верификация Meta webhook и приём входящих сообщений/статусов |
| **Telegram Bot API** | `POST /webhooks/telegram/:bot_token` | Вебхук входящих сообщений и команд бота |
| **Instagram Direct (Meta)** | `GET /webhooks/instagram`<br>`POST /webhooks/instagram` | Верификация подписки и приём Direct-сообщений |
| **Evolution API (Входящие)** | `POST /api/v1/accounts/:account_id/conversations/:conversation_id/messages` | Evolution API передаёт входящие WhatsApp-сообщения в Axioma |
| **Evolution API (Исходящие)** | `POST https://api.axioma.tj/chatwoot/webhook/:instance_name` | Axioma отправляет ответ оператора в Evolution API шлюз |
| **Realtime WebSockets** | `GET /cable` (WebSocket Upgrade) | ActionCable шина мгновенных пуш-уведомлений в Vue-дашборд |

---

## 🚀 4. CI/CD пайплайн и процесс выкатки (Release Flow)

```
[develop] (Разработка и фичи)
    │
    ▼ (Pull Request + Тесты)
[master] (Стабильный релизный код)
    │
    ▼ (git tag v0.1.0 && git push origin v0.1.0)
[GitHub Actions] (Автоматическая сборка Docker-образа)
    │
    ▼
[GHCR: ghcr.io/bakhtiyor-aminzoda/axioma:v0.1.0]
    │
    ▼ (VPS: указать AXIOMA_IMAGE_TAG=v0.1.0 в .env и docker compose pull)
[Production VPS]
```

### Развёртывание на VPS:
На сервере **не требуется держать git-репозиторий с веткой develop**. Достаточно рабочей директории `/opt/axioma/`:
1. `docker-compose.production.yaml`
2. `.env` (с ключами и `AXIOMA_IMAGE_TAG=v0.1.0`)
3. Конфигурации Nginx `/etc/nginx/sites-available/axioma`

```bash
# 1. Загрузить указанную версию
docker compose -f docker-compose.production.yaml pull

# 2. При первом запуске инициализировать базу
docker compose -f docker-compose.production.yaml run --rm rails bundle exec rails db:chatwoot_prepare

# 3. Запустить контейнеры
docker compose -f docker-compose.production.yaml up -d
```

---

## 🔄 5. Процедура обновления (Minimal Downtime Rolling Update)

> [!NOTE]
> На одном VPS с одним экземпляром Puma и локальной базой данных **абсолютный Zero-Downtime технически невозможен**: перезапуск контейнера занимает 5–15 секунд.
> Честное название для такой схемы — **Minimal Downtime Update** (минимальный простой во время планового окна обслуживания).

```bash
cd /opt/axioma

# 1. Скачать свежий проверенный образ
docker compose -f docker-compose.production.yaml pull rails sidekiq

# 2. Применить миграции базы данных (если есть)
docker compose -f docker-compose.production.yaml run --rm rails bundle exec rails db:migrate

# 3. Пересоздать контейнеры с минимальным перерывом (~5-10 сек)
docker compose -f docker-compose.production.yaml up -d --no-deps rails sidekiq

# 4. Проверить статус
docker compose -f docker-compose.production.yaml ps
```

---

## 🛡️ 6. Безопасность и защита от SSRF

### Почему `SAFE_FETCH_ALLOW_PRIVATE_NETWORK` ОБЯЗАН быть `false`:
- Модуль `SafeFetch` в Axioma используется при отправке исходящих Webhook'ов и скачивании аватарок/вложений по URL.
- При `SAFE_FETCH_ALLOW_PRIVATE_NETWORK=true` отключается библиотека `ssrf_filter`. Любой администратор или пользователь, настроивший вебхук или указавший URL аватарки, мог бы совершить **SSRF-атаку** (Server-Side Request Forgery) на:
  - `http://127.0.0.1:6379` (Redis — неавторизованные команды)
  - `http://postgres:5432` (PostgreSQL)
  - `http://169.254.169.254` (Cloud Metadata AWS/DO/Hetzner — кража токенов сервера)
  - Внутренние Docker-контейнеры (`http://evolution_api:8080/instance/...`).
- **Решение:** В продакшне `SAFE_FETCH_ALLOW_PRIVATE_NETWORK=false` включён по умолчанию. Все обращения к локальным и приватным сетям RFC1918 строго блокируются. Входящие сообщения из WhatsApp/Telegram идут через публичный Nginx с SSL, что исключает необходимость открывать приватную сеть.

---

## 📱 7. Стратегия каналов WhatsApp (Dual Strategy)

### Уровень 1: Официальный WhatsApp Cloud API (Meta Graph API)
- **Для кого:** Средний и крупный бизнес (клиники, банки, ритейл-сети, дистрибьюторы).
- **Плюсы:** 100% официальный канал, **нулевой риск блокировки номера**, подтверждённая зеленая галочка, официальные шаблоны рассылок от Meta, высокая пропускная способность (до 80 сообщений/сек).
- **Подключение:** Через встроенный в Axioma канал `Channel::Whatsapp` с провайдером `whatsapp_cloud` (указывается `Phone Number ID` и `System User Access Token` из Meta Business Manager).

### Уровень 2: Evolution API (QR-код через Baileys)
- **Для кого:** Микробизнес и небольшие торговые точки, у которых ещё нет юридического лица или верификации в Facebook Business.
- **Плюсы:** Быстрое подключение за 30 секунд сканированием QR-кода прямо со смартфона владельца.
- **Риски:** Имитация WhatsApp Web. При агрессивном спаме или массовых не запрошенных рассылках алгоритмы Meta могут временно или навсегда заблокировать номер.
- **Позиционирование:** Предоставляется с четким предупреждением: *"Подключение по QR-коду предназначено для обработки входящих обращений клиентов. Запрещено использовать для холодного спама"*.

---

## 🗄️ 8. Хранилище медиафайлов: Cloudflare R2

В нашем целевом сегменте ожидается значительный объём медиа: **голосовые сообщения, фотографии товаров, чеки и короткие видео**, поэтому медиафайлы вынесены в S3-compatible storage.

**Cloudflare R2** идеально подходит для этого сценария:
- 10 GB-month бесплатного Standard Storage;
- 1 млн Class A операций (запись) и 10 млн Class B операций (чтение) в месяц бесплатно;
- **Исходящий трафик (egress) не тарифицируется ($0 Egress fee)**.

```bash
# Добавить в .env:
ACTIVE_STORAGE_SERVICE=s3_compatible
STORAGE_ACCESS_KEY_ID=<your_r2_access_key>
STORAGE_SECRET_ACCESS_KEY=<your_r2_secret_key>
STORAGE_REGION=auto
STORAGE_BUCKET_NAME=axioma-media-production
STORAGE_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com
STORAGE_FORCE_PATH_STYLE=true
```

---

## 💾 9. Резервное копирование и верификация Disaster Recovery

Скрипт `deploy/backup-to-s3.sh` реализует полную схему офсайт-бэкапов:
1. Дамп PostgreSQL (`pg_dump | gzip -9`).
2. Архивация конфигураций (`.env`, `docker-compose.production.yaml`, Nginx).
3. Загрузка в Cloudflare R2 / AWS S3.
4. Ротация GFS: 7 ежедневных, 4 еженедельных, 3 ежемесячных.

### Проведённые практические испытания:
- **Test 1 («Kill the server»):** Выполнен `docker compose restart`. Все 12 аккаунтов, 10 контактов, 7 диалогов, 64 сообщения, 248 быстрых ответов и 95 атрибутов восстановились со 100% целостностью.
- **Test 2 (Full Disaster Recovery Restore):** Выполнен дамп рабочей базы и полное восстановление в чистую тестовую БД `chatwoot_restore_test`. Все сущности, схемы, индексы и кириллические/таджикские символы восстановились с нулевыми ошибками.

---

## 👥 10. Предотвращение коллизий операторов (Concurrency Control)

В Axioma реализован двухуровневый механизм защиты от дублирования ответов:
1. **Визуальный индикатор набора текста (Typing Indicator):** Когда один оператор начинает ввод ответа, на экранах остальных операторов над полем ввода появляется бейдж: `[Имя оператора] навишта истодааст... (печатает...)`.
2. **Назначение диалога (Assignment):** Регламентное правило для операторов — при взятии диалога в работу оператор нажимает «Назначить мне». После этого диалог закрепляется за ним, исключая параллельные ответы.

---

## 🎯 11. План первого дня пилота (Milestone: «Ни одного потерянного клиента»)

**Сценарий:** 3 оператора реального магазина (ноутбук Chrome, смартфон PWA, ноутбук Safari) работают полный день через Axioma.

- [ ] Входящее сообщение в WhatsApp появляется одновременно у всех 3 операторов.
- [ ] Оператор 1 назначает чат на себя; Оператор 2 видит статус назначения.
- [ ] Оператор 1 использует быстрый ответ `/корт` и `/чек`.
- [ ] Голосовое сообщение покупателя воспроизводится без задержек.
- [ ] Внутренняя заметка менеджера остаётся скрытой от покупателя.
- [ ] Диалог, отложенный на 24 часа, автоматически открывается при ответе клиента.