# claude_agy — шаблон связки Claude Code + Antigravity CLI

Шаблон проекта для экономии токенов Claude: Claude проектирует и ревьюит, Antigravity (`agy`) пишет код и гоняет тесты, PowerShell-скрипт связывает их, git-ветка страхует.

```text
Claude Code  -> /agy-handoff  -> контракт (spec + критерии + промпт)
Claude Code  -> /agy-implement -> tools/invoke-antigravity.ps1 -> agy пишет код и тестирует
Claude Code  -> перезапускает тесты сам + читает diff -> ACCEPT / NEEDS_FIXES / REJECT
ты           -> commit / merge вручную
```

## Установка из GitHub — одна и та же команда для нового и существующего проекта

Открой PowerShell **в папке проекта** и вставь этот блок (он всегда одинаковый, менять ничего не нужно):

```powershell
$t = "$env:TEMP\agy-tpl"
if (Test-Path $t) { Remove-Item -Recurse -Force $t }
git clone --depth 1 https://github.com/DEDOKRU/claude-agy-template.git $t
powershell -ExecutionPolicy Bypass -File $t\tools\install-into-project.ps1 -Target .
Remove-Item -Recurse -Force $t
```

Что происходит: свежая копия шаблона скачивается с GitHub во временную папку, установщик добавляет workflow в текущий проект, временная папка удаляется. Репозиторий приватный — авторизацию даёт Git Credential Manager, токены не нужны.

Установщик идемпотентен (можно перезапускать), ничего не перезаписывает:
- копирует скрипт-мост, команды `/agy-handoff` + `/agy-implement` и шаблоны handoff;
- **дописывает** секцию правил в существующий `CLAUDE.md` (или создаёт его);
- **дописывает** `.agent_handoff/**/logs/` в `.gitignore`;
- добавляет путь проекта в `trustedWorkspaces` agy (без этого headless-запуски agy виснут).

После установки: проверь `git status`, закоммить новые файлы — цикл готов.

### Новый проект с нуля

1. github.com/DEDOKRU/claude-agy-template → кнопка **Use this template** → Create a new repository → имя нового репо.
2. `git clone https://github.com/DEDOKRU/<имя>.git C:\AI\<папка>` — файлы workflow уже внутри.
3. В папке проекта выполни тот же блок установки, что выше — файлы он пропустит (уже есть), но зарегистрирует папку в `trustedWorkspaces`.

### Существующий проект

Только шаг с блоком установки — всё.

## Разовая настройка машины (уже сделано, если читаешь это на исходной машине)

1. Antigravity CLI установлен, `agy` в PATH (`agy --version`).
2. Один раз `agy` интерактивно: Google OAuth + trust workspace.
3. Модель по умолчанию задаётся в agy; список — `agy models`. Можно переопределить: `/agy-implement` -> скрипт с `-Model "<имя>"`.

## Структура

```text
.claude/commands/agy-handoff.md    # Claude: создать контракт для agy
.claude/commands/agy-implement.md  # Claude: запустить agy и отревьюить
tools/invoke-antigravity.ps1       # мост: проверки, checkpoint, запуск agy, сводка
.agent_handoff/current/            # рабочие файлы текущей задачи
.agent_handoff/current/logs/       # сырые логи agy (в .gitignore, Claude их не читает)
CLAUDE.md                          # правила для Claude в этом репо
```

## Предохранители

- Скрипт отказывается работать на `main`/`master` и без handoff-файлов.
- Перед запуском agy — checkpoint-коммит: `git diff HEAD` показывает ровно правки агента, откат = `git reset --hard <checkpoint>`.
- agy запускается с `--sandbox`; `--dangerously-skip-permissions` скрипт принимает только вместе с sandbox.
- `--print-timeout 30m` (дефолтные 5 минут agy обрезали бы реальную задачу).
- Отчёты agy считаются недоверенными: Claude обязан сам перезапустить тесты перед вердиктом ACCEPT.
- Claude не коммитит, не мержит и не пушит — это делаешь ты.

## Проверено на живом прогоне (2026-07-02)

- Полный цикл handoff -> agy -> ревью пройден (ветка `agy/smoke-test`), вердикт ACCEPT.
- В print-режиме agy сам подтверждает свои тулы (запись файлов, команды) при `--sandbox` — `-SkipPermissions` для обычных задач не нужен.
- Грабли, уже учтённые в скрипте: agy виснет на открытом stdin (скрипт закрывает его через `$null |`); дефолтный print-timeout agy всего 5 минут (скрипт ставит 30); agy молча самообновляется при старте (разовая пауза до пары минут — это не зависание).
- `agy models` печатает список только в реальном интерактивном терминале.
