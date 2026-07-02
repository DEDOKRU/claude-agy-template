# claude_agy — шаблон связки Claude Code + Antigravity CLI

Шаблон проекта для экономии токенов Claude: Claude проектирует и ревьюит, Antigravity (`agy`) пишет код и гоняет тесты, PowerShell-скрипт связывает их, git-ветка страхует.

```text
Claude Code  -> /agy-handoff  -> контракт (spec + критерии + промпт)
Claude Code  -> /agy-implement -> tools/invoke-antigravity.ps1 -> agy пишет код и тестирует
Claude Code  -> перезапускает тесты сам + читает diff -> ACCEPT / NEEDS_FIXES / REJECT
ты           -> commit / merge вручную
```

## Как склонировать под новый проект

```powershell
# 1. Скопируй шаблон (или git clone, если выложишь в remote)
Copy-Item -Recurse C:\AI\claude_agy C:\AI\my_new_project
Set-Location C:\AI\my_new_project
Remove-Item -Recurse -Force .git
git init -b main
git add -A; git commit -m "init from claude_agy template"

# 2. Первый раз в этой папке запусти agy интерактивно и подтверди trust workspace
agy
# внутри: /quit
```

Дальше — обычный цикл в Claude Code: `/agy-handoff <задача>`, затем `/agy-implement`.

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
