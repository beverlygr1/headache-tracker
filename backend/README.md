# Backend

FastAPI + PostgreSQL backend для проекта ГПО АОИ-2508.

## Реализовано

- регистрация и логин;
- JWT access + refresh tokens;
- профиль пользователя;
- сохранение прогресса онбординга на аккаунте (`PUT /api/v1/user/onboarding`);
- CRUD приступов;
- дневник факторов с upsert по дате;
- базовая агрегированная аналитика;
- CSV-экспорт;
- PostgreSQL через SQLAlchemy;
- Alembic migrations;
- Swagger/OpenAPI;
- интеграционный API-тест.

`/analytics/triggers`, PDF-экспорт и `/forecast/risk` намеренно отвечают `501 Not Implemented`: для них пока нет достоверной реализации.

## Локальный запуск без Docker

При обновлении существующей БД также выполните `alembic upgrade head`.
Миграция `0002_onboarding` добавляет состояние онбординга; пользователи с
существующими наблюдениями продолжают работу без повторного знакомства.
Подробности — `docs/ONBOARDING.md` в корне репозитория.

1. Создайте PostgreSQL БД `headache_tracker`.
2. Скопируйте `.env.example` в `.env`.
3. Установите зависимости:

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
```

4. Примените миграции и запустите API:

```bash
alembic upgrade head
fastapi dev app/main.py
```

Swagger: `http://127.0.0.1:8000/docs`  
Health: `http://127.0.0.1:8000/health`

## Тесты

```bash
pip install -r requirements-dev.txt
pytest -q
```
