# ГПО АОИ-2508

Стартовый monorepo мобильного приложения для отслеживания приступов головной боли.

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

## Самый простой запуск backend: Docker

Из корня проекта:

```bash
docker compose up --build
```

После запуска:

- API: `http://127.0.0.1:8000`
- Swagger: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Health: `http://127.0.0.1:8000/health`

Миграции Alembic применяются автоматически при старте backend-контейнера.

## Запуск backend без Docker

```bash
cd backend
python -m venv .venv
```

Windows:

```bash
.venv\Scripts\activate
```

macOS/Linux:

```bash
source .venv/bin/activate
```

Далее:

```bash
pip install -r requirements.txt
```

Создайте PostgreSQL БД `headache_tracker`, скопируйте `.env.example` в `.env`, затем:

```bash
alembic upgrade head
fastapi dev app/main.py
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

Это лучше, чем возвращать тестовый медицинский прогноз как будто он настоящий.

## Postman

Импортируйте файл:

```text
postman/GPO_AOI_2508.postman_collection.json
```

Запустите всю коллекцию через **Run collection** (или по порядку вручную):

1. `Auth / Register` — генерирует новый email, поэтому повторный прогон не падает с 409;
2. `Auth / Login` и `Auth / Refresh` — сохраняют access/refresh token;
3. `Profile` — получение и обновление профиля;
4. `Attacks` — создание (ID сохраняется в `attackId`), список, получение, обновление;
5. `Diary` — upsert, получение по дате, список;
6. `Analytics` — summary и CSV-экспорт;
7. `Not implemented yet (501)` — ожидаемо возвращают 501;
8. `Cleanup / Delete attack`.

У каждого запроса есть проверка статуса. Из консоли:

```bash
npx newman run postman/GPO_AOI_2508.postman_collection.json
```

Время без часового пояса (`2026-09-23T12:00:00`) backend считает UTC; ответы всегда в UTC.

## Backend tests

```bash
cd backend
pip install -r requirements-dev.txt
pytest -q
```

Тест использует временную SQLite БД только как изолированную БД автоматизированного теста. Рабочая БД приложения остаётся PostgreSQL.

## Flutter

UI пока не требуется. В `mobile/lib` уже лежит REST API-клиент на Dio для согласованных endpoint'ов.

Если Android/iOS каталоги ещё не созданы:

```bash
cd mobile
flutter create . --platforms=android,ios
flutter pub get
```

Android Emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Для физического устройства укажите локальный IP компьютера с backend.

## Важное перед production

- замените `JWT_SECRET_KEY`;
- включите HTTPS на reverse proxy;
- ограничьте CORS;
- добавьте rate limiting для auth;
- продумайте отзыв refresh-токенов / logout на сервере;
- добавьте CI, резервное копирование PostgreSQL и централизованные логи;
- ML/медицинские рекомендации не включайте до отдельной валидации модели и продуктовых требований.
