# 🚀 Axioma CRM — Production Deployment & Operations Guide

> **Axioma CRM** — Единая система коммуникаций и воронки продаж для бизнеса Таджикистана.
> Все сообщения (WhatsApp, Instagram, Telegram, Web chat) в одном рабочем пространстве для ваших операторов.

---

## 🏛 1. Архитектура MVP (Single-Node VPS)

Рекомендованная конфигурация для первого этапа (10–50 бизнесов, 50–200 операторов):
* **Сервер:** 1 VPS (Ubuntu 22.04 / 24.04 LTS)
* **Характеристики:** 4 vCPU, 8 GB RAM, 80–100 GB NVMe SSD (Hetzner / DigitalOcean / локальный ЦОД в ТЧ)
* **Сеть & Порты:** 80 (HTTP), 443 (HTTPS), 22 (SSH). Порты БД (5432) и Redis (6379) закрыты внутри Docker-сети.

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

## 📦 2. Используемые Docker-образы

| Сервис | Образ | Назначение |
| :--- | :--- | :--- |
| **Axioma Web & Sidekiq** | `ghcr.io/bakhtiyor-aminzoda/axioma:latest` | CRM веб-интерфейс, REST API, ActionCable, фоновые задачи |
| **PostgreSQL** | `pgvector/pgvector:pg16` | Основная база данных (мультитенантная изоляция) |
| **Redis** | `redis:7-alpine` | Кэш, сессии, очереди Sidekiq |
| **Evolution API** | `evoapicloud/evolution-api:latest` | WhatsApp шлюз для Таджикистана (QR-код и Baileys) |
| **Reverse Proxy** | `nginx:alpine` или хостовый Nginx | SSL-терминация, gzip-сжатие, вебсокеты |

---

## 🚀 3. Быстрый запуск на сервере (Step-by-Step)

### Шаг 1. Подготовка сервера
```bash
# Клонирование репозитория или копирование директории deploy/
git clone https://github.com/bakhtiyor-aminzoda/axioma.git /opt/axioma
cd /opt/axioma

# Запуск скрипта подготовки (установка Docker, настройка swap, firewall)
chmod +x deploy/setup-server.sh
sudo deploy/setup-server.sh
```

### Шаг 2. Настройка переменных окружения
```bash
cp deploy/env.production.example .env
nano .env
```
> **Обязательно заполните в `.env`:**
> 1. `SECRET_KEY_BASE` — сгенерируйте через `openssl rand -hex 64`
> 2. `POSTGRES_PASSWORD` — надежный пароль БД
> 3. `REDIS_PASSWORD` — надежный пароль Redis
> 4. `EVOLUTION_API_KEY` — ключ доступа к Evolution API
> 5. `FRONTEND_URL` — `https://crm.axioma.tj`

### Шаг 3. Запуск контейнеров
```bash
docker compose -f docker-compose.production.yaml pull
docker compose -f docker-compose.production.yaml up -d
```

### Шаг 4. Инициализация базы данных (только при первом запуске)
```bash
docker compose -f docker-compose.production.yaml exec -T rails bundle exec rails db:chatwoot_prepare
```

### Шаг 5. Настройка Nginx и получение SSL (Let's Encrypt)
```bash
sudo cp deploy/nginx.conf.example /etc/nginx/sites-available/axioma
sudo ln -s /etc/nginx/sites-available/axioma /etc/nginx/sites-enabled/
sudo nginx -t

# Получение SSL сертификатов:
sudo certbot --nginx -d crm.axioma.tj -d api.axioma.tj
sudo systemctl reload nginx
```

---

## 🔄 4. Процедура обновления (Zero-Downtime Update)

Когда в ветку `develop` или `master` пушатся изменения, GitHub Actions автоматически собирает новый образ в GHCR: `ghcr.io/bakhtiyor-aminzoda/axioma:latest`.

Для обновления продакшн-сервера выполните:

```bash
cd /opt/axioma

# 1. Скачать свежий образ из GHCR
docker compose -f docker-compose.production.yaml pull rails sidekiq

# 2. Применить новые миграции БД (если были)
docker compose -f docker-compose.production.yaml exec -T rails bundle exec rails db:migrate

# 3. Перезапустить веб и фоновые воркеры
docker compose -f docker-compose.production.yaml up -d --no-deps rails sidekiq

# 4. Проверить статус
docker compose -f docker-compose.production.yaml ps
```

---

## 🛡️ 5. Production Security Checklist

- [x] **Изоляция мультитенантности (Account Isolation):** Проверена тестами — ни один запрос не имеет доступа к данным чужого аккаунта.
- [x] **Защита баз данных:** Порты PostgreSQL (5432) и Redis (6379) закрыты от внешнего интернета и слушают только локальный/docker интерфейс.
- [x] **Публичная регистрация:** `ENABLE_ACCOUNT_SIGNUP=false` — предотвращает несанкционированную регистрацию сторонних лиц.
- [x] **Автоматическое открытие диалогов:** При входящем сообщении от клиента (`incoming`) диалог со статусом `pending` или `resolved` гарантированно открывается (`open`), исключая потерю обращений.
- [x] **Секреты:** Все пароли и токены вынесены в `.env` (добавлен в `.gitignore`), в коде отсутствуют захардкоженные секреты.
- [x] **Резервное копирование:** Настройте cron-дамп PostgreSQL:
  ```bash
  # Добавить в /etc/crontab:
  0 3 * * * root docker exec axioma_postgres pg_dump -U postgres chatwoot_production | gzip > /opt/backups/axioma_$(date +\%Y\%m\%d).sql.gz
  ```

---

## 👥 6. Автоматическая инициализация аккаунтов (Axioma Onboarding)

При создании любого нового бизнес-аккаунта модуль `Axioma::TemplateSeeder` автоматически создаёт:
1. **Быстрые ответы (Quick Replies / Canned Responses):**
   * На русском (`/привет`, `/наличие`, `/доставка`, `/заказ`, `/оплата`, `/чек_принят`, `/менеджер`)
   * На таджикском (`/салом`, `/ҳасти`, `/интиқол`, `/дархост`, `/корт`, `/чек`, `/менеҷер`, `/рахмат`, `/нархнома`)
2. **Метки и сегментация (Labels / Tags):**
   * Статусные: `new`, `hot`, `vip`, `lead`, `wholesale`, `repeat`, `payment_pending`, `delivery`, `complaint`, `lost`
   * Локализованные: `новый`, `в_работе`, `оплачено`, `лиди_гарм`, `дар_коркард`, `интизори_пардохт`
3. **Категории и поля клиентов (Contact Custom Attributes):**
   * Категория клиента (`client_category`: Новый, Потенциальный, Постоянный, VIP, Оптовый, Неактивный, Проблемный)
   * Шаҳр / Город (`shahr`: Душанбе, Худжанд, Бохтар, Куляб и др.)
   * Компания / Бренд (`nomi_shirkat`)
   * Размер команды (`shumorai_operatoron`)
   * Сумма сделки (`mablaghi_muomila`)
   * Заметки (`qaydho`)
4. **Стандартные отделы (Teams):**
   * Отдел продаж («Шӯъбаи фурӯш»)
   * Служба поддержки («Дастгирии техникӣ»)
