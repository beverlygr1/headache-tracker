# Headache Tracker — Flutter UI

Flutter-клиент для FastAPI backend из папки `backend/`.

## Реализованные экраны

- онбординг после авторизации с сохранением шага и завершения на аккаунте;
- ежедневная запись самочувствия (сон, вода, стресс) и история этих записей;

- вход и регистрация (JWT access + refresh);
- «Сегодня»;
- создание и редактирование записи приступа;
- дневник приступов с фильтром;
- подробности приступа;
- профиль с выходом из аккаунта (аватар или вкладка «Профиль»).

Работают переходы, изменение интенсивности, выбор времени, добавление своих
областей и симптомов, завершение приступа, редактирование и фильтрация дневника.
Приступы хранятся на backend (`/api/v1/attacks`).

## Работа с backend

```text
lib/core/api/api_client.dart        Dio, Bearer token, авто-refresh при 401
lib/core/api/api_exception.dart     понятные сообщения об ошибках (сеть, 4xx/5xx, 422)
lib/features/*/data/*_api.dart      запросы к endpoint'ам
lib/features/attacks/data/attack_dto.dart     модель приступа из API (UTC ↔ локальное время)
lib/features/profile/data/user_profile.dart   модель профиля
lib/features/tracker/data/attack_repository.dart  API ↔ доменная модель AttackRecord
lib/features/tracker/state/tracker_controller.dart  загрузка, сохранение, ошибки
lib/features/auth/state/auth_controller.dart   сессия, вход, регистрация, выход
```

- Первая загрузка показывает индикатор, при ошибке — экран с кнопкой «Повторить».
- Списки обновляются жестом pull-to-refresh.
- Ошибки сохранения показываются во всплывающем сообщении, кнопка блокируется
  на время запроса.
- Если access token истёк, клиент один раз обновляет его через `/auth/refresh`
  и повторяет запрос; если refresh не удался — возвращает на экран входа.

### Демо-режим без backend

Новый онбординг с пустым дневником:

```powershell
flutter run -d chrome --dart-define=ONBOARDING_DEMO=true
```

Подробности сценария, миграции и передачи через Git — в `docs/ONBOARDING.md`
в корне репозитория. Для обычного запуска перед обновлением клиента примените
миграцию бэкенда `alembic upgrade head`.

Прежнее демо с примерами приступов:

```powershell
flutter run -d chrome --dart-define=DEMO_MODE=true
```

## Запуск в браузере

Нужен установленный Flutter SDK (канал stable, Dart ≥ 3.5).

Из папки `mobile/` выполните:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Проект содержит полноценную папку `web`. На широком экране интерфейс
автоматически ограничивается шириной 430 пикселей и выглядит как мобильное
приложение.

## Добавление Android и Windows

Из папки `mobile/` один раз выполните:

```powershell
flutter create --platforms=android,windows .
flutter pub get
```

После этого:

```powershell
flutter run -d windows
flutter run -d emulator-5554
```

## Адрес backend

Сначала запустите backend (см. `backend/README.md` или `docker compose up`
в корне репозитория). CORS для Flutter web (localhost на любом порту)
уже разрешён в backend по умолчанию.

API-клиент читает адрес из `API_BASE_URL`.

Для браузера или Windows:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Для Android Emulator значение по умолчанию уже подходит:

```text
http://10.0.2.2:8000/api/v1
```
