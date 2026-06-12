# 🗺 Nynorsk Coach 2.0: Roadmap to Native Excellence

Цель: Превратить приложение в нативный инструмент экосистемы Apple, использующий передовые технологии iOS (Widgets, Vision, App Intents).

---

## 🏗 Phase 1: Глубокая интеграция (Widgets & Spotlight)
*Задача: Сделать так, чтобы приложение было полезным, даже когда оно закрыто.*

- [ ] **Настройка App Groups**
    - [ ] Включить Capability "App Groups" для основного таргета.
    - [ ] Настроить SwiftData container для работы через App Group (чтобы виджет видел базу).
- [ ] **Home Screen Widget (Слово дня)**
    - [ ] Создать Target `WidgetExtension`.
    - [ ] Реализовать `TimelineProvider` (обновление раз в сутки).
    - [ ] UI: Small & Medium виджеты (Слово + Перевод + Градиент сложности).
- [ ] **Lock Screen Widget**
    - [ ] Реализовать Circular Widget (прогресс/стрик).
    - [ ] Реализовать Inline Widget (текстовое слово дня над часами).
- [ ] **Spotlight Search**
    - [ ] Индексация слов через `CoreSpotlight`.
    - [ ] Реализация открытия конкретного слова из поиска iPhone.

---

## 📷 Phase 2: Vision & Camera (Real-world Learning)
*Задача: Превратить камеру телефона в переводчик реальности.*

- [ ] **Сканер текста (Live Text)**
    - [ ] Интеграция `VisionKit` (`DataScannerViewController`).
    - [ ] Распознавание норвежского текста в реальном времени.
    - [ ] Тап по слову на камере -> Мгновенный перевод через наш словарь/AI.
- [ ] **AI Object Recognition (Опционально)**
    - [ ] Использование `CoreML` (MobileNetV2 или аналог) для распознавания предметов.
    - [ ] Маппинг классов предметов на Nynorsk (Chair -> Ein Stol).

---

## 📰 Phase 3: Живой контент (RSS & Context)
*Задача: Дать пользователю реальный контекст языка.*

- [ ] **RSS Reader (NRK Nynorsk)**
    - [ ] Написать парсер XML/RSS ленты `nrk.no/nynorsk`.
    - [ ] UI: Лента новостей с картинками.
- [ ] **Интерактивное чтение**
    - [ ] При клике на слово в новости — поиск в локальном словаре.
    - [ ] Если слова нет — быстрый запрос к OpenAI ("Переведи в контексте этой новости").
    - [ ] Кнопка "Добавить в словарь" прямо из статьи.

---

## 🗣 Phase 4: Siri & Shortcuts (App Intents)
*Задача: Голосовое управление и автоматизация.*

- [ ] **App Intents**
    - [ ] Интент `OpenDailyWord` ("Hey Siri, show me the word of the day").
    - [ ] Интент `StartQuiz` ("Hey Siri, practice Nynorsk").
- [ ] **Interactive Notifications**
    - [ ] Rich Notifications: Викторина прямо в пуше (нажать и удерживать, чтобы выбрать ответ).

---

## 🎨 Phase 5: Polish & Release
*Задача: Подготовка к App Store.*

- [ ] **App Icon**: Финальный дизайн иконки.
- [ ] **Launch Screen**: Анимированный экран загрузки.
- [ ] **Review**: Финальный прогон по App Store Guidelines.
