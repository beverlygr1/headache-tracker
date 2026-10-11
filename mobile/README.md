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

## Android

Платформа Android уже добавлена (`android/`, applicationId
`ru.gpo2508.headache_tracker_app`, на устройстве — «Дневник боли»).

### Подготовка (один раз)

1. Установите [Android Studio](https://developer.android.com/studio).
   При первом запуске мастер скачает Android SDK.
2. В Android Studio: **Settings → Plugins** → установите плагин **Flutter**
   (Dart установится вместе с ним), перезапустите IDE.
3. **Settings → Languages & Frameworks → Android SDK → SDK Tools**:
   отметьте **Android SDK Command-line Tools** → Apply.
4. В терминале:

   ```powershell
   flutter doctor --android-licenses   # принять все лицензии (y)
   flutter doctor                      # строка Android toolchain должна быть [√]
   ```

5. Эмулятор: **Device Manager → Create Virtual Device** → например, Pixel 7,
   образ API 35 (x86_64) → Finish → запустите ▶.

Если путь к проекту содержит кириллицу или пробелы и сборка падает
с ошибками путей, перенесите клон, например, в `C:\projects\headache-tracker`.

### Запуск на эмуляторе

1. Запустите backend (из корня репозитория `docker compose up --build`)
   и проверьте `http://127.0.0.1:8000/health`.
2. **File → Open** → папка `mobile` (не `mobile/android`).
   Если Android Studio предложит, выполните **Pub get**.
3. Сверху выберите эмулятор и `main.dart` → **Run ▶**.

Или из терминала:

```powershell
flutter emulators --launch <имя>   # список: flutter emulators
flutter run
```

Для эмулятора ничего настраивать не нужно: адрес по умолчанию
`http://10.0.2.2:8000/api/v1`, а `10.0.2.2` внутри эмулятора — это ваш компьютер.

### Сборка APK

```powershell
flutter build apk --release
```

Файл: `build/app/outputs/flutter-apk/app-release.apk`. Установка на
запущенный эмулятор — перетащить APK в окно эмулятора или `flutter install`.

Такой APK ходит на `10.0.2.2`, то есть работает только в эмуляторе.
Для настоящего телефона укажите адрес компьютера в той же Wi-Fi-сети
(`ipconfig` → IPv4-адрес):

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1
```

Backend должен слушать `0.0.0.0` (в Docker Compose так и есть; при ручном
запуске — `fastapi run app/main.py --host 0.0.0.0`), а брандмауэр Windows —
пропускать порт 8000.

Release-сборка пока подписана debug-ключом: подходит для установки
и демонстрации, но не для Google Play. Приложение обращается к backend
по HTTP (`usesCleartextTraffic` в `AndroidManifest.xml`) — убрать после
перехода backend на HTTPS.

## Адрес backend

Сначала запустите backend (см. `backend/README.md` или `docker compose up`
в корне репозитория). CORS для Flutter web (localhost на любом порту)
уже разрешён в backend по умолчанию.

API-клиент читает адрес из `API_BASE_URL`.

Для браузера:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Для Android Emulator значение по умолчанию уже подходит:

```text
http://10.0.2.2:8000/api/v1
```
