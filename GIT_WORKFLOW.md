# Работа с GitHub

Краткая инструкция для участников проекта.

## Первый запуск

1. Скопировать ссылку на репозиторий на GitHub.
2. Открыть терминал в VS Code.
3. Выполнить:

```bash
git clone <ссылка-на-репозиторий>
cd <название-репозитория>
code .
```

## Перед началом новой задачи

Обновить `main`:

```bash
git checkout main
git pull origin main
```

Создать отдельную ветку:

```bash
git checkout -b feature/название-задачи
```

Пример:

```bash
git checkout -b feature/profile-screen
```

## После выполнения задачи

Проверить изменения:

```bash
git status
```

Сохранить их:

```bash
git add .
git commit -m "feat: краткое описание задачи"
```

Отправить ветку на GitHub:

```bash
git push -u origin feature/название-задачи
```

Если ветка уже была отправлена ранее:

```bash
git push
```

## Pull Request

После `push`:

1. Открыть репозиторий на GitHub.
2. Создать Pull Request из своей ветки в `main`.
3. Назначить ревьюера.
4. Не сливать Pull Request самостоятельно до проверки.
5. После замечаний внести исправления, сделать новый commit и `git push`.
6. После `Approve` изменения можно объединить с `main`.

## Главное правило

**Напрямую в `main` не пушим.**

Рабочая схема:

`main → feature-ветка → commit → push → Pull Request → review → merge`
