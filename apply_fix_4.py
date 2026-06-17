#!/usr/bin/env python3
"""
Apply Fix #4 — оставшиеся правки App Group ID.
Меняет хардкод `group.com.abzac.NynorskCoach` на `Constants.appGroupIdentifier`
в коде main app и виджета. Добавляет assertionFailure в fallback-ветку.

ЗАПУСК:
    cd <папка с NynorskCoach.xcodeproj>
    python3 apply_fix_4.py

Скрипт делает бэкапы в .audit_backups/ перед изменениями.
Идемпотентен — повторный запуск ничего не сломает.
"""
import sys
from pathlib import Path
from datetime import datetime


# (относительный путь, старый паттерн, новый паттерн, описание)
EDITS = [
    (
        "NynorskCoach/Services/NynorskCoachApp.swift",
        'forSecurityApplicationGroupIdentifier: "group.com.abzac.NynorskCoach"',
        'forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier',
        "Заменить хардкод App Group ID на Constants",
    ),
    (
        "NynorskWidget/NynorskWidget.swift",
        'let appGroup = "group.com.abzac.NynorskCoach"',
        'let appGroup = Constants.appGroupIdentifier  // см. Constants.swift',
        "Заменить хардкод App Group ID на Constants",
    ),
]

# Дополнительная правка: добавить assertionFailure в fallback-ветку.
# Это многострочный паттерн — если whitespace не совпадёт, скрипт скажет
# про это и попросит сделать руками.
APP_FILE = "NynorskCoach/Services/NynorskCoachApp.swift"
ASSERTION_OLD = """} else {
            modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
        }"""
ASSERTION_NEW = """} else {
            // Этот fallback сработает только если entitlements рассинхронизированы
            // с Constants.appGroupIdentifier. В проде должна работать ветка выше.
            assertionFailure("App Group container недоступен — проверь entitlements")
            modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
        }"""


def main() -> int:
    project_root = Path.cwd()
    print(f"📂 Working in: {project_root}\n")

    # Проверка: запускаемся из корня проекта
    if not (project_root / "NynorskCoach.xcodeproj").exists():
        print("❌ Не вижу NynorskCoach.xcodeproj в текущей папке.")
        print(f"   Перейди в корень проекта и запусти оттуда:")
        print(f"     cd /path/to/ProjectNC")
        print(f"     python3 {Path(__file__).name}")
        return 1

    # Бэкапы
    backup_dir = project_root / ".audit_backups" / datetime.now().strftime("fix_4_%Y%m%d_%H%M%S")
    backup_dir.mkdir(parents=True, exist_ok=True)
    print(f"💾 Бэкапы в: {backup_dir.relative_to(project_root)}\n")

    changes_made = 0
    skipped = 0
    errors = 0

    # Основные правки
    for rel_path, old, new, desc in EDITS:
        file_path = project_root / rel_path
        if not file_path.exists():
            print(f"❌ {rel_path}: файл не найден")
            errors += 1
            continue

        content = file_path.read_text(encoding="utf-8")

        if old in content:
            # Бэкап
            backup_file = backup_dir / rel_path.replace("/", "__")
            backup_file.write_text(content, encoding="utf-8")
            # Замена
            content = content.replace(old, new)
            file_path.write_text(content, encoding="utf-8")
            print(f"✅ {rel_path}")
            print(f"   {desc}")
            changes_made += 1
        elif new in content:
            print(f"⏭  {rel_path}: уже применено, пропускаю")
            skipped += 1
        else:
            print(f"⚠️  {rel_path}: паттерн не найден, нужна проверка вручную")
            print(f"   Искал: {old[:80]}...")
            errors += 1
        print()

    # Доп правка: assertionFailure в fallback
    app_file = project_root / APP_FILE
    if app_file.exists():
        content = app_file.read_text(encoding="utf-8")
        if ASSERTION_OLD in content:
            backup_file = backup_dir / (APP_FILE.replace("/", "__") + ".assertion")
            backup_file.write_text(content, encoding="utf-8")
            content = content.replace(ASSERTION_OLD, ASSERTION_NEW)
            app_file.write_text(content, encoding="utf-8")
            print(f"✅ {APP_FILE}")
            print(f"   Добавлен assertionFailure в else-ветку")
            changes_made += 1
        elif "assertionFailure(\"App Group container" in content:
            print(f"⏭  {APP_FILE}: assertionFailure уже добавлен, пропускаю")
            skipped += 1
        else:
            print(f"⚠️  {APP_FILE}: не нашёл точный паттерн else-блока для assertionFailure")
            print(f"   Возможно, отличается отступ или формат — добавь вручную:")
            print(f"   в else-блок перед modelConfiguration =")
            print(f"   ModelConfiguration(isStoredInMemoryOnly: false) добавь:")
            print(f'     assertionFailure("App Group container недоступен — проверь entitlements")')
            errors += 1
        print()

    # Итог
    print("─" * 60)
    print(f"✅ Применено: {changes_made}")
    print(f"⏭  Пропущено (уже сделано): {skipped}")
    print(f"⚠️  Требует внимания: {errors}")
    print()
    if changes_made > 0:
        print("Дальше:")
        print("  git diff               # посмотреть что изменилось")
        print("  # в Xcode: Clean Build Folder (⇧⌘K), пересобери, проверь виджет")
        print()
        print("Откатиться если что:")
        print(f"  cp {backup_dir.relative_to(project_root)}/* <обратно_по_путям>")

    return 0 if errors == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
