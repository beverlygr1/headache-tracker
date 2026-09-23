# Мобильное приложение для отслеживания головных болей

Проект разрабатывается в рамках дисциплины «Групповое проектное обучение (ГПО-2508)».

## О проекте

Мобильное приложение для ведения дневника головных болей, отслеживания возможных триггеров и прогнозирования риска приступа.

## Стек

- Flutter + Dart: мобильный клиент;
- FastAPI + Python: REST backend;
- PostgreSQL: основная серверная БД;
- SQLAlchemy 2: ORM;
- Alembic: миграции БД;
- JWT: access/refresh авторизация;
- SQLite: **не используется в приложении на этом этапе**. Его стоит добавлять позже только при необходимости офлайн-режима или локального кэша;
- ML: зарезервирован на следующий этап, когда появятся данные и критерии модели.

## Структура

```text
backend/                  FastAPI backend
  app/
    api/                  routers и зависимости
    core/                 config + JWT/password security
    db/                   SQLAlchemy session
    models/               User, Attack, DiaryEntry
    repositories/         слой доступа к данным
    schemas/              Pydantic API contracts
    services/             auth и analytics logic
  migrations/             Alembic
  tests/                  API integration test
mobile/                   Flutter API-каркас
postman/                  готовая Postman collection
original_api_draft/       исходные main.py и schemas.py

docker-compose.yml        PostgreSQL + backend
```

## Что уже работает с PostgreSQL

1. `POST /api/v1/auth/register` — регистрация пользователя.
2. `POST /api/v1/auth/login` — access + refresh JWT.
3. `POST /api/v1/auth/refresh` — обновление JWT.
4. `GET/PUT /api/v1/user/profile` — профиль.
5. `POST/GET/PUT/DELETE /api/v1/attacks` — реальные записи приступов в БД.
6. `PUT/GET /api/v1/diary` — дневник факторов.
7. `GET /api/v1/analytics/summary` — базовая статистика по реальным приступам.
8. `GET /api/v1/analytics/export?format=csv` — CSV-выгрузка.

Пока намеренно не реализованы и возвращают HTTP 501:

- `GET /api/v1/analytics/triggers`;
- `GET /api/v1/analytics/export?format=pdf`;
- `GET /api/v1/forecast/risk`.

