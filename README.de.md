# claude-agy-template

[English](README.md) | **Deutsch** | [Русский](README.ru.md)

Eine Projektvorlage, die **Claude Code** (Architekt & Reviewer) mit **Antigravity CLI** (`agy`, Implementierer) kombiniert, um Claude-Tokens zu sparen: Claude schreibt den Vertrag und prüft das Ergebnis; agy schreibt den Code und führt die Tests aus; ein PowerShell-Skript verbindet beide; ein Git-Branch dient als Sicherung.

```text
Claude Code  -> /agy-handoff   -> Vertrag (Spezifikation + Abnahmekriterien + Prompt)
Claude Code  -> /agy-implement -> tools/invoke-antigravity.ps1 -> agy implementiert & testet
Claude Code  -> führt die Verifikation selbst erneut aus + liest den Diff -> ACCEPT / NEEDS_FIXES / REJECT
du           -> Commit / Merge manuell
```

Warum das Tokens spart: Claude schreibt keinen Boilerplate-Code, überwacht keine Testläufe und liest nie das ganze Projekt erneut. Die teure Arbeit (Implementierung, Debugging roter Tests, Wiederholungsläufe) läuft über Antigravity auf der Gemini-Seite.

## Voraussetzungen

- Windows mit PowerShell 5.1+ (Bridge und Installer sind PowerShell-Skripte)
- [Claude Code](https://code.claude.com) CLI
- [Antigravity CLI](https://antigravity.google) — `agy` im PATH, einmal interaktiv eingeloggt
- git

## Installation — derselbe Block für neue und bestehende Projekte

Öffne PowerShell **im Projektordner** und füge diesen Block unverändert ein:

```powershell
$t = "$env:TEMP\agy-tpl"
if (Test-Path $t) { Remove-Item -Recurse -Force $t }
git clone --depth 1 https://github.com/DEDOKRU/claude-agy-template.git $t
powershell -ExecutionPolicy Bypass -File $t\tools\install-into-project.ps1 -Target .
Remove-Item -Recurse -Force $t
```

Der Installer ist idempotent (kann gefahrlos erneut ausgeführt werden) und überschreibt nie deine Inhalte:

- kopiert das Bridge-Skript, die Befehle `/agy-handoff` + `/agy-implement` und die Handoff-Vorlagen;
- **ergänzt** einen Regelabschnitt in deiner bestehenden `CLAUDE.md` (oder legt sie an);
- **ergänzt** `.agent_handoff/**/logs/` in `.gitignore`;
- registriert den Projektpfad in agys `trustedWorkspaces` (ohne diesen Eintrag hängen Headless-Läufe).

### Szenario 1: neues Projekt

1. Auf GitHub den Button **Use this template** → eigenes Repository anlegen.
2. Lokal per `git clone` holen.
3. Den Installationsblock im Ordner ausführen — Dateien werden übersprungen (schon vorhanden), aber der Workspace wird bei agy registriert.

### Szenario 2: bestehendes Projekt

1. Sicherstellen, dass es ein Git-Repository mit mindestens einem Commit ist (`git init` + Initial-Commit falls nicht — Checkpoint/Rollback/Diff brauchen eine Basislinie).
2. Installationsblock ausführen, `git status` prüfen, committen.
3. Claude Code im Projekt neu starten, damit die neuen Befehle geladen werden.

### Szenario 3: bereits angebundenes Projekt aktualisieren

Der Installer überschreibt absichtlich keine vorhandenen Dateien; Updates laufen daher über Löschen:

```powershell
Remove-Item tools\invoke-antigravity.ps1, .claude\commands\agy-handoff.md, .claude\commands\agy-implement.md
```

Danach den Installationsblock erneut ausführen — er holt frische Kopien.

## Der Arbeitszyklus

1. `/agy-handoff <Aufgabenbeschreibung>` — Claude erstellt einen Arbeitsbranch `agy/<name>` und den Vertrag: was zu tun ist, welche Dateien angefasst werden dürfen, wie verifiziert wird, Abnahmekriterien.
2. `/agy-implement` — die Bridge erstellt einen Checkpoint-Commit, agy implementiert und verifiziert (typisch 5–30 Min.), dann prüft Claude: führt die Verifikationsbefehle selbst erneut aus, gleicht den Diff mit der Liste erlaubter Dateien ab, geht die Abnahmekriterien durch.
3. Urteil:
   - **ACCEPT** — du mergst (oder öffnest einen PR).
   - **NEEDS_FIXES** — das Feedback steht bereits in `REVIEW_NOTES.md`; `/agy-implement continue` ausführen, agy korrigiert in derselben Konversation, Claude prüft erneut.
   - **REJECT** — Rollback mit `git reset --hard <checkpoint>` (Hash wird vom Skript ausgegeben) und neues Handoff schreiben.

Die einzigen manuellen Aktionen im gesamten Zyklus sind die beiden Befehle oben und der finale Merge: Claude committet, mergt und pusht nie — das ist eine Sicherung.

## Delegation ist der Standard — keine Größenschwelle

Das größte Leck in jedem Token-Spar-Setup ist der Agent, der entscheidet: „Diese Änderung ist zu klein, um sie zu delegieren." Die in `CLAUDE.md` installierten Regeln entfernen dieses Ermessen daher vollständig:

- **Jede** Codeänderung läuft durch den agy-Zyklus — ein Einzeiler-Fix und ein 10-Dateien-Feature kosten dieselbe Delegationsrunde, also existiert keine „zu klein"-Schwelle.
- Der einzige Auslöser für eine direkte Bearbeitung durch Claude ist deine explizite Aufforderung in der aktuellen Nachricht („mach es selbst", „ohne agy", „Schnellmodus"). Die Erlaubnis wird nie aus Kontext, Dringlichkeit oder der Offensichtlichkeit des Fixes abgeleitet.
- Das gilt auch beim Review: ein trivialer Befund (Tippfehler, roter Test, Einzeiler) geht in `REVIEW_NOTES.md` und zurück an agy — der Reviewer „fixt" ihn nie schnell selbst.

Das allgemeine Muster: Jede Anweisung, die einem Agenten die Wahl zwischen „billig per Delegation" und „teuer, aber sofort" nach eigenem Ermessen lässt, führt früher oder später dazu, dass er den teuren Weg genau dort wählt, wo das Sparen am wichtigsten war — beim Strom häufiger kleiner Änderungen. Die Regel muss das Ermessen entfernen, nicht lenken.

## Sicherungen

- Die Bridge verweigert den Lauf auf `main`/`master` und ohne Handoff-Dateien.
- Checkpoint-Commit vor jedem agy-Lauf: `git diff HEAD` zeigt exakt die Änderungen des Agenten; Rollback ist ein einziger Befehl.
- agy läuft mit `--sandbox`; `--dangerously-skip-permissions` wird nur zusammen mit dem Sandbox-Modus akzeptiert.
- `--print-timeout 30m` (agys 5-Minuten-Standard würde echte Aufgaben abschneiden).
- agys Berichte gelten als nicht vertrauenswürdig: Claude muss die Verifikationsbefehle vor einem ACCEPT selbst erneut ausführen.
- Verifikationsbefehle passen zum Aufgabentyp: Test-Suite für langlebigen Code, einfacher Lauf + Plausibilitätskriterien für einmalige Research-Skripte.

## Token-Hygiene (deine Gewohnheiten — die Vorlage kann das nicht automatisieren)

- **`/clear` nach jeder abgeschlossenen Aufgabe.** Eine endlose Session über 20 Aufgaben ist der größte Limit-Killer: veralteter Kontext wird bei jeder Nachricht berechnet. Vorher `/rename <name>`, falls du zurückkehren willst.
- **Claude zweimal korrigiert? Kein drittes Mal.** Der Kontext ist verunreinigt; `/clear` plus ein präziserer Prompt ist billiger und funktioniert besser.
- **`/context` und `/mcp` regelmäßig prüfen.** Ungenutzte MCP-Server kosten bei jeder Nachricht Kontext — deaktiviere, was die aktuelle Arbeit nicht braucht.
- **`/compact` mit Anweisung, nicht nackt**: `/compact behalte nur die aktive Aufgabe, geänderte Dateien, Entscheidungen, Verifikationsbefehl und nächsten Schritt` (dieselbe Regel steckt in der Projekt-`CLAUDE.md`, sodass auch die Auto-Kompaktierung sie beachtet).
- **Lege für größere Projekte eine `PROJECT_MAP.md`** im Repo-Root an (Vorlage in `.agent_handoff/templates/`) — Claude liest die Karte statt den Baum zu durchlaufen.
- **Unterbrochene Arbeit wird aus einer Datei fortgesetzt, nicht aus dem Chat-Gedächtnis**: Die Projektregeln verlangen bei mehrsitzigen Aufgaben eine gepflegte `.agent_handoff/current/SESSION_STATE.md` — eine frische Session startet daraus, statt Kontext teuer zu rekonstruieren.

## In Live-Läufen entdeckte Fallstricke (von den Skripten bereits behandelt)

- agy wartet im `-p`-Print-Modus auf stdin-EOF und hängt ewig an einer offenen Pipe — die Bridge schließt stdin über eine `$null |`-Pipe.
- Ein Workspace, der in `trustedWorkspaces` (`~/.gemini/antigravity-cli/settings.json`) fehlt, lässt Headless-Läufe hängen — der Installer registriert ihn.
- agy aktualisiert sich beim Start stillschweigend selbst (ein Download, der wie ein Hänger aussieht — eine einmalige Pause).
- agys Standard-Print-Timeout beträgt nur 5 Minuten — die Bridge setzt 30.
- `agy models` gibt seine Liste nur in einem echten interaktiven Terminal aus.
- PowerShell 5.1 liest BOM-lose Skripte in der ANSI-Codepage: ein UTF-8-Gedankenstrich wird zu einem typografischen Anführungszeichen, das das String-Parsing bricht — beide Skripte sind deshalb reines ASCII.

## Repository-Struktur

```text
.claude/commands/agy-handoff.md    # Claude: Vertrag für agy erstellen
.claude/commands/agy-implement.md  # Claude: agy ausführen und reviewen
tools/invoke-antigravity.ps1       # Bridge: Checks, Checkpoint, agy-Lauf, Zusammenfassung
tools/install-into-project.ps1     # Installer für neue/bestehende Projekte
.agent_handoff/templates/          # Vorlagen für Vertrag, Session-State und Projektkarte
CLAUDE.md                          # Regeln für Claude in diesem Repo
```

## Lizenz

[MIT](LICENSE)
