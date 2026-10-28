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
- явная отметка наличия боли в дневнике (`headache_present`);
- график интенсивности по дням (`GET /api/v1/analytics/intensity`);
- одинаковые календарные периоды и часовые пояса для сводки и графика.

Контракты спринта, примеры запросов и критерии приёмки:
[../docs/SPRINT_BACKEND.md](../docs/SPRINT_BACKEND.md).
Новая миграция `0003_diary_headache` сохраняет историю; старые дни остаются
без отметки наличия боли (`null`).

Экраны выбора зон боли и проверки записи используют существующий CRUD
приступов. Несколько зон передаются в `localization` строкой через `, `
(до 120 символов); симптомы — массивом `symptoms`. Создание выполняется
через `POST /api/v1/attacks`, редактирование — через `PUT /api/v1/attacks/{id}`.
Новая миграция для этих экранов не нужна. Сохранение, повторное чтение,
редактирование и доступ к записям проверяются в `tests/test_pain_zones.py`.

`/analytics/triggers` и PDF-экспорт намеренно отвечают `501 Not Implemented`.

`GET /api/v1/forecast/risk` работает: `status=ready` с вероятностью либо
`status=insufficient_data` с `probability=null` и недостающими полями сегодняшнего
дневника (сон, стресс, кофеин). Ответ содержит `calculated_at`, `prediction_date`,
`time_zone` и `horizon_days=1`. При ошибке модели — `503`; остальные разделы
продолжают работать, модель загружается при первом достаточном запросе.
Подробный контракт: [../docs/FORECAST_API.md](../docs/FORECAST_API.md).
Для этого обновления не нужна новая миграция БД.

## Фото и личные данные профиля

- `PUT /api/v1/user/avatar` — multipart-поле `file`, JPEG/PNG/WebP до 2 МБ;
  тип проверяется по содержимому файла. Ответ — профиль.
- `GET /api/v1/user/avatar` — байты фото владельца токена (404 — фото нет).
- `DELETE /api/v1/user/avatar` — удалить фото.
- `GET /api/v1/user/profile` возвращает `avatar_updated_at` (`null` — фото нет).
- `PUT /api/v1/user/profile` принимает `birth_date`, `gender`, `time_zone`;
  явный `null` очищает поле.

Фото хранится в таблице `user_avatars` (миграция `0007_user_avatars`),
поэтому после обновления выполните `alembic upgrade head` (Docker Compose
делает это при старте).

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
