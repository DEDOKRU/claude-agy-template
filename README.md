# claude_agy — шаблон связки Claude Code + Antigravity CLI

Шаблон проекта для экономии токенов Claude: Claude проектирует и ревьюит, Antigravity (`agy`) пишет код и гоняет тесты, PowerShell-скрипт связывает их, git-ветка страхует.

```text
Claude Code  -> /agy-handoff  -> контракт (spec + критерии + промпт)
Claude Code  -> /agy-implement -> tools/invoke-antigravity.ps1 -> agy пишет код и тестирует
Claude Code  -> перезапускает тесты сам + читает diff -> ACCEPT / NEEDS_FIXES / REJECT
ты           -> commit / merge вручную
```

## Стандартный блок установки

Один и тот же блок для всех сценариев ниже. Открой PowerShell **в папке проекта** и вставь как есть — менять ничего не нужно:

```powershell
$t = "$env:TEMP\agy-tpl"
if (Test-Path $t) { Remove-Item -Recurse -Force $t }
git clone --depth 1 https://github.com/DEDOKRU/claude-agy-template.git $t
powershell -ExecutionPolicy Bypass -File $t\tools\install-into-project.ps1 -Target .
Remove-Item -Recurse -Force $t
```

Что происходит: свежая копия шаблона скачивается с GitHub во временную папку, установщик добавляет workflow в текущий проект (`-Target .` — текущая папка), временная папка удаляется. Репозиторий приватный — авторизацию даёт Git Credential Manager, токены не нужны.

Установщик идемпотентен (можно перезапускать), ничего не перезаписывает:
- копирует скрипт-мост, команды `/agy-handoff` + `/agy-implement` и шаблоны handoff;
- **дописывает** секцию правил в существующий `CLAUDE.md` (или создаёт его);
- **дописывает** `.agent_handoff/**/logs/` в `.gitignore`;
- добавляет путь проекта в `trustedWorkspaces` agy (без этого headless-запуски agy виснут).

## Сценарий 1: новый проект с нуля

1. **Создай репо из шаблона (в браузере).** github.com/DEDOKRU/claude-agy-template → кнопка **Use this template** → **Create a new repository** → имя проекта → Private → Create. Новый репо получает файлы workflow с чистой историей.
2. **Склонируй на диск:**
   ```powershell
   git clone https://github.com/DEDOKRU/<имя>.git C:\AI\<папка>
   cd C:\AI\<папка>
   ```
3. **Выполни стандартный блок установки** (ты уже в папке проекта). По всем файлам будет `already present, skipped` — это нормально; важна строка `added to agy trustedWorkspaces`.
4. Запусти Claude Code в папке проекта — рабочий цикл готов.

## Сценарий 2: существующий проект

1. **Проверь, что проект — git-репозиторий.** Если нет: `git init` + первый коммит. Установщик без git откажется работать.
2. **Выполни стандартный блок установки** из папки проекта. Он скопирует файлы workflow, допишет `CLAUDE.md` и `.gitignore`, зарегистрирует папку у agy.
3. **Посмотри и закоммить:**
   ```powershell
   git status
   git add -A
   git commit -m "add agy delegation workflow"
   ```
4. **Перезапусти Claude Code**, если он был открыт в этом проекте — чтобы подхватились новые команды и обновлённый `CLAUDE.md`.

## Сценарий 3: обновить workflow в уже подключённом проекте

Установщик намеренно не перезаписывает существующие файлы (чтобы не затереть локальные правки), поэтому обновление — через удаление старых копий:

```powershell
Remove-Item tools\invoke-antigravity.ps1, .claude\commands\agy-handoff.md, .claude\commands\agy-implement.md
```

Затем стандартный блок установки — он положит свежие версии с GitHub.

## Рабочий цикл (одинаковый во всех проектах)

1. В Claude Code: `/agy-handoff <описание задачи>` — Claude создаёт рабочую ветку `agy/<имя>` и контракт: что делать, какие файлы можно трогать, какие тесты гонять, критерии приёмки.
2. `/agy-implement` — скрипт делает checkpoint-коммит, agy пишет код и гоняет тесты (обычно 5–30 минут), затем Claude ревьюит: сам перезапускает тесты, сверяет diff со списком разрешённых файлов, проходит по критериям.
3. По вердикту:
   - **ACCEPT** — ты делаешь merge в main (или PR).
   - **NEEDS_FIXES** — замечания уже в `REVIEW_NOTES.md`; запускаешь `/agy-implement continue`, agy правит в той же сессии, Claude ревьюит заново.
   - **REJECT** — откат: `git reset --hard <checkpoint>` (хэш печатает скрипт) и новый handoff с другой постановкой.

Ручные действия во всём цикле — только команды из пунктов 1–2 и финальный merge: Claude не коммитит, не мержит и не пушит, это предохранитель.

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
