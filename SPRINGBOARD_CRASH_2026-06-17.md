# SpringBoard Crash — Widget Add Attempt

**Дата:** 2026-06-17 23:35:37 +0200
**Симулятор:** iPhone 17 Pro Max (UDID `6FFC1EF9-310C-43B5-BDF3-69D7C7DD15FD`)
**Хост:** iMac Pro, macOS 15.7.7
**Контекст:** Пользователь попытался добавить виджет NynorskCoach на домашний экран симулятора после применения SwiftData VersionedSchema (`SchemaV1` + `NynorskCoachMigrationPlan`). SpringBoard упал во время анимации добавления виджета.

## Диагноз

**Этот краш НЕ наш.** SpringBoard упал в собственном коде анимации ряби на домашнем экране (`-[SBHRippleSimulation clear]` → `EXC_BAD_ACCESS`). Виджет NynorskCoach не успел запуститься — SpringBoard свалился раньше, ещё на UIKit animation.

Это известная нестабильность симулятора Xcode при добавлении виджетов, не связанная с кодом конкретного приложения. На реальном устройстве не воспроизводится.

## Ключевые поля краша

- **Process:** `SpringBoard` (com.apple.springboard, PID 53766)
- **Exception:** `EXC_BAD_ACCESS (SIGSEGV)` — `KERN_INVALID_ADDRESS at 0xfffffffffffffff8`
- **Crashed thread:** main thread, com.apple.main-thread
- **Top frame:** `-[SBHRippleSimulation clear] + 74` в `SpringBoardHome.framework`
- **Trigger:** dispatch source callback, не из нашего кода

## Что делать

1. **Не править на основе этого отчёта.** Виджет, возможно, в порядке — мы просто не дошли до его выполнения.
2. **Перепроверить на реальном устройстве** после App Store sandbox-теста.
3. **Если виджет всё-таки крашится на реальном устройстве** — этот отчёт пригодится как baseline для исключения "не наш ли это код".

## Полный отчёт

```
Incident Identifier: 40386F0B-CB5A-4A93-B3A2-2979AD9FBC64
CrashReporter Key:   143B52D2-3725-4F84-F488-7FC76DB0ECD6
Hardware Model:      iMacPro1,1
Process:             SpringBoard [53766]
Path:                /Volumes/VOLUME/*/SpringBoard.app/SpringBoard
Identifier:          com.apple.springboard
Version:             1.0 (50)
Code Type:           X86-64 (Native)
Role:                Foreground
Parent Process:      launchd_sim [53763]
Coalition:           com.apple.CoreSimulator.SimDevice.6FFC1EF9-310C-43B5-BDF3-69D7C7DD15FD [64256]
Responsible Process: SimulatorTrampoline [848]

Date/Time:           2026-06-17 23:35:37.6747 +0200
Launch Time:         2026-06-17 23:34:03.8802 +0200
OS Version:          macOS 15.7.7 (24G720)
Release Type:        User

Exception Type:  EXC_BAD_ACCESS (SIGSEGV)
Exception Subtype: KERN_INVALID_ADDRESS at 0xfffffffffffffff8
Exception Codes: 0x0000000000000001, 0xfffffffffffffff8
Termination Reason: SIGNAL 11 Segmentation fault: 11

Triggered by Thread:  0

Thread 0 Crashed::  Dispatch queue: com.apple.main-thread
0   SpringBoardHome   -[SBHRippleSimulation clear] + 74
1   SpringBoardHome   -[SBHRippleSimulation createRippleAtGridCoordinate:strength:] + 73
2   libdispatch.dylib _dispatch_client_callout + 6
3   libdispatch.dylib _dispatch_continuation_pop + 859
4   libdispatch.dylib _dispatch_source_invoke + 2178
5   libdispatch.dylib _dispatch_main_queue_drain + 732
6   libdispatch.dylib _dispatch_main_queue_callback_4CF + 31
7   CoreFoundation    __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__ + 9
8   CoreFoundation    __CFRunLoopRun + 2386
9   CoreFoundation    _CFRunLoopRunSpecificWithOptions + 496
10  GraphicsServices  GSEventRunModal + 94
11  UIKitCore         -[UIApplication _run] + 842
12  UIKitCore         UIApplicationMain + 123
13  SpringBoard       SBSystemAppMain + 7639
15  dyld              start + 3056
```

Полный лог с register state и binary images — в архиве у Apple, можно запросить через CrashReporter Key.
