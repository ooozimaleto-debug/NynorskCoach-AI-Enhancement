import Foundation
import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    // Ключ для сохранения языка
    private let kLanguageKey = "nativeLanguage"
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: kLanguageKey)
        }
    }
    
    // Свойство для получения кода локали (исправленное)
    var localeIdentifier: String {
        switch currentLanguage {
        case "Russian": return "ru"
        case "Ukrainian": return "uk"
        case "Polish": return "pl"
        case "Bokmål": return "nb"
        default: return "en"
        }
    }
    
    private init() {
            // 1. Пытаемся загрузить сохраненный выбор (если пользователь уже менял язык вручную)
            if let saved = UserDefaults.standard.string(forKey: kLanguageKey) {
                self.currentLanguage = saved
            } else {
                // 2. Если запускаем впервые — определяем язык системы УМНО
                // iOS может вернуть "ru-RU", "ru_US", "en-GB" и т.д.
                // Мы проверяем только начало кода (префикс).
                
                let langCode = Locale.current.language.languageCode?.identifier ?? "en"
                
                if langCode.hasPrefix("ru") {
                    self.currentLanguage = "Russian"
                } else if langCode.hasPrefix("uk") {
                    self.currentLanguage = "Ukrainian"
                } else if langCode.hasPrefix("pl") {
                    self.currentLanguage = "Polish"
                } else if langCode.hasPrefix("nb") || langCode.hasPrefix("no") || langCode.hasPrefix("nn") {
                    self.currentLanguage = "Bokmål" // Норвежский
                } else {
                    self.currentLanguage = "English" // Для всех остальных (немцы, французы и т.д.)
                }
            }
        }
    
    // --- СЛОВАРЬ ПЕРЕВОДОВ (ОБНОВЛЕННЫЙ) ---
    private let uiTranslations: [String: [String: String]] = [
        // Табы
        "Учить": ["Russian": "Учить", "English": "Learn", "Ukrainian": "Вчити", "Polish": "Uczyć się", "Bokmål": "Lære"],
        "Практика": ["Russian": "Практика", "English": "Practice", "Ukrainian": "Практика", "Polish": "Praktyka", "Bokmål": "Øving"],
        "Профиль": ["Russian": "Профиль", "English": "Profile", "Ukrainian": "Профіль", "Polish": "Profil", "Bokmål": "Profil"],
        
        // Главная
        "Темы": ["Russian": "Темы", "English": "Topics", "Ukrainian": "Теми", "Polish": "Tematy", "Bokmål": "Temaer"],
        "Экзамен": ["Russian": "Экзамен", "English": "Exam", "Ukrainian": "Екзамен", "Polish": "Egzamin", "Bokmål": "Eksamen"],
        "Викторина": ["Russian": "Викторина", "English": "Quiz", "Ukrainian": "Вікторина", "Polish": "Quiz", "Bokmål": "Quiz"],

        // Квесты (ДИНАМИЧЕСКИЕ - без цифр в тексте)
        "Ежедневные цели": ["Russian": "Ежедневные цели", "English": "Daily Goals", "Ukrainian": "Щоденні цілі", "Polish": "Cele dzienne", "Bokmål": "Daglige mål"],
        "quest_words": ["Russian": "Повторение слов", "English": "Word Practice", "Ukrainian": "Повторення слів", "Polish": "Powtórka słów", "Bokmål": "Ordrepetisjon"],
        "quest_lesson": ["Russian": "Завершение уроков", "English": "Complete Lessons", "Ukrainian": "Завершення уроків", "Polish": "Fullfør leksjoner", "Bokmål": "Fullfør leksjoner"],
        "quest_coins": ["Russian": "Поиск монет", "English": "Coin Hunt", "Ukrainian": "Пошук монет", "Polish": "Myntjakt", "Bokmål": "Myntjakt"],
        "Забрать": ["Russian": "Забрать", "English": "Claim", "Ukrainian": "Забрати", "Polish": "Odbierz", "Bokmål": "Hent"],
        // --- ПРАКТИКА (ИСПЫТАНИЯ И СИМУЛЯЦИИ) ---
        "Live Text": ["Russian": "Live Text", "English": "Live Text", "Ukrainian": "Live Text", "Polish": "Live Text", "Bokmål": "Live Text"],
        "Глаз Одина": ["Russian": "Глаз Одина", "English": "Odin's Eye", "Ukrainian": "Око Одіна", "Polish": "Oko Odyna", "Bokmål": "Odins øye"],
        "Фото-квиз": ["Russian": "Фото-квиз", "English": "Photo Quiz", "Ukrainian": "Фото-квіз", "Polish": "Foto-quiz", "Bokmål": "Foto-quiz"],
        "В кафе": ["Russian": "В кафе", "English": "At the Café", "Ukrainian": "У кафе", "Polish": "W kawiarni", "Bokmål": "På kafé"],
        "У врача": ["Russian": "У врача", "English": "At the Doctor", "Ukrainian": "У лікаря", "Polish": "U lekarza", "Bokmål": "Hos legen"],
        "Магазин": ["Russian": "Магазин", "English": "Shop", "Ukrainian": "Магазин", "Polish": "Sklep", "Bokmål": "Butikk"],
        "Стройка": ["Russian": "Стройка", "English": "Construction", "Ukrainian": "Будівництво", "Polish": "Budowa", "Bokmål": "Byggeplass"],
        "Офис": ["Russian": "Офис", "English": "Office", "Ukrainian": "Офіс", "Polish": "Biuro", "Bokmål": "Kontor"],
        "Свободный": ["Russian": "Свободный", "English": "Free Talk", "Ukrainian": "Вільний", "Polish": "Wolny", "Bokmål": "Fri prat"],
        "Quiz": ["Russian": "Quiz", "English": "Quiz", "Ukrainian": "Quiz", "Polish": "Quiz", "Bokmål": "Quiz"],
        // --- ЭКЗАМЕН И СКАНЕР (НОВОЕ) ---
        "Мало знаний для экзамена": ["Russian": "Мало знаний для экзамена", "English": "Not enough knowledge for exam", "Ukrainian": "Мало знань для іспиту", "Polish": "Za mało wiedzy", "Bokmål": "For lite kunnskap"],
        "Выучи хотя бы 5 слов, прежде чем приходить сюда.": ["Russian": "Выучи 5 слов.", "English": "Learn 5 words first.", "Ukrainian": "Вивчи 5 слів.", "Polish": "Naucz się 5 słów.", "Bokmål": "Lær 5 ord først."],
        "Подготовка билетов...": ["Russian": "Подготовка билетов...", "English": "Preparing tickets...", "Ukrainian": "Підготовка білетів...", "Polish": "Przygotowanie...", "Bokmål": "Forbereder billetter..."],
        "Сдаться": ["Russian": "Сдаться", "English": "Give Up", "Ukrainian": "Здатися", "Polish": "Poddaj się", "Bokmål": "Gi opp"],
        "Завершить": ["Russian": "Завершить", "English": "Finish", "Ukrainian": "Завершити", "Polish": "Zakończ", "Bokmål": "Fullfør"],
        "Экзамен сдан!": ["Russian": "Экзамен сдан!", "English": "Exam Passed!", "Ukrainian": "Іспит складено!", "Polish": "Egzamin zdany!", "Bokmål": "Eksamen bestått!"],
        "На пересдачу!": ["Russian": "На пересдачу!", "English": "Retake!", "Ukrainian": "На перездачу!", "Polish": "Poprawka!", "Bokmål": "Prøv igjen!"],
        "Как переводится": ["Russian": "Как переводится", "English": "How do you translate", "Ukrainian": "Як перекладається", "Polish": "Jak przetłumaczyć", "Bokmål": "Hvordan oversettes"],
        "Напиши на Nynorsk": ["Russian": "Напиши на Nynorsk", "English": "Write in Nynorsk", "Ukrainian": "Напиши на Nynorsk", "Polish": "Napisz w Nynorsk", "Bokmål": "Skriv på Nynorsk"],
        "Ответить": ["Russian": "Ответить", "English": "Answer", "Ukrainian": "Відповісти", "Polish": "Odpowiedz", "Bokmål": "Svar"],
        "Сканер": ["Russian": "Сканер", "English": "Scanner", "Ukrainian": "Сканер", "Polish": "Skaner", "Bokmål": "Skanner"],
        "Выбор слов": ["Russian": "Выбор слов", "English": "Select Words", "Ukrainian": "Вибір слів", "Polish": "Wybór słów", "Bokmål": "Velg ord"],
        "Ищем слова...": ["Russian": "Ищем слова...", "English": "Looking for words...", "Ukrainian": "Шукаємо слова...", "Polish": "Szukam słów...", "Bokmål": "Ser etter ord..."],
        "Другое фото": ["Russian": "Другое фото", "English": "Other Photo", "Ukrainian": "Інше фото", "Polish": "Inne zdjęcie", "Bokmål": "Annet bilde"],
        "Нажми на слово": ["Russian": "Нажми на слово", "English": "Tap a word", "Ukrainian": "Натисни на слово", "Polish": "Dotknij słowa", "Bokmål": "Trykk på et ord"],
        "Фото-сканер": ["Russian": "Фото-сканер", "English": "Photo Scanner", "Ukrainian": "Фото-сканер", "Polish": "Foto-skanner", "Bokmål": "Foto-skanner"],
        "Сфотографируй текст, чтобы спокойно выделять и переводить слова.": ["Russian": "Сфотографируй текст для перевода.", "English": "Photo to translate.", "Ukrainian": "Сфотографуй текст.", "Polish": "Zrób zdjęcie tekstu.", "Bokmål": "Ta bilde av tekst."],
        "Камера": ["Russian": "Камера", "English": "Camera", "Ukrainian": "Камера", "Polish": "Aparat", "Bokmål": "Kamera"],
        "Галерея": ["Russian": "Галерея", "English": "Gallery", "Ukrainian": "Галерея", "Polish": "Galeria", "Bokmål": "Galleri"],
        "Сообщение...": ["Russian": "Сообщение...", "English": "Message...", "Ukrainian": "Повідомлення...", "Polish": "Wiadomość...", "Bokmål": "Melding..."],
        
        // --- БИБЛИОТЕКА: НОВОСТИ И ГЕНЕРАТОРЫ ---
        "Новости": ["Russian": "Новости", "English": "News", "Ukrainian": "Новини", "Polish": "Wiadomości", "Bokmål": "Nyheter"],
        "Новости (NRK)": ["Russian": "Новости (NRK)", "English": "News (NRK)", "Ukrainian": "Новини (NRK)", "Polish": "Wiadomości (NRK)", "Bokmål": "Nyheter (NRK)"],
        "Загрузка новостей...": ["Russian": "Загрузка новостей...", "English": "Loading news...", "Ukrainian": "Завантаження новин...", "Polish": "Ładowanie wiadomości...", "Bokmål": "Laster nyheter..."],
        "Нет новостей": ["Russian": "Нет новостей", "English": "No news", "Ukrainian": "Немає новин", "Polish": "Brak wiadomości", "Bokmål": "Ingen nyheter"],
        "Проверьте интернет или попробуйте позже.": ["Russian": "Проверьте интернет.", "English": "Check internet connection.", "Ukrainian": "Перевірте інтернет.", "Polish": "Sprawdź internet.", "Bokmål": "Sjekk internett."],
        "Обновить": ["Russian": "Обновить", "English": "Refresh", "Ukrainian": "Оновити", "Polish": "Odśwież", "Bokmål": "Oppdater"],
        // Истории
        "Например: Тролль, который любил кофе": ["Russian": "Напр: Тролль, который любил кофе", "English": "E.g. A troll who loved coffee", "Ukrainian": "Напр: Троль, що любив каву", "Polish": "Np. Troll, który kochał kawę", "Bokmål": "F.eks. Et troll som elsket kaffe"],
        "Сказка": ["Russian": "Сказка", "English": "Fairy Tale", "Ukrainian": "Казка", "Polish": "Bajka", "Bokmål": "Eventyr"],
        "Детектив": ["Russian": "Детектив", "English": "Detective", "Ukrainian": "Детектив", "Polish": "Kryminał", "Bokmål": "Krim"],
        "Факты о Норвегии": ["Russian": "Факты о Норвегии", "English": "Facts about Norway", "Ukrainian": "Факти про Норвегію", "Polish": "Fakty o Norwegii", "Bokmål": "Fakta om Norge"],
        "Смешная история": ["Russian": "Смешная история", "English": "Funny Story", "Ukrainian": "Смішна історія", "Polish": "Zabawna historia", "Bokmål": "Morsom historie"],
        "Диалог": ["Russian": "Диалог", "English": "Dialogue", "Ukrainian": "Діалог", "Polish": "Dialog", "Bokmål": "Dialog"],
                
        // Подкасты (Тона и поля)
        "Новый подкаст": ["Russian": "Новый подкаст", "English": "New Podcast", "Ukrainian": "Новий подкаст", "Polish": "Nowy podcast", "Bokmål": "Ny podcast"],
        "О чем будет подкаст?": ["Russian": "О чем будет подкаст?", "English": "What is it about?", "Ukrainian": "Про що буде подкаст?", "Polish": "O czym będzie?", "Bokmål": "Hva handler den om?"],
        "Например: Викинги обсуждают биткойн": ["Russian": "Напр: Викинги и биткойн", "English": "E.g. Vikings and Bitcoin", "Ukrainian": "Напр: Вікінги та біткоїн", "Polish": "Np. Wikingowie i Bitcoin", "Bokmål": "F.eks. Vikinger og Bitcoin"],
        "Повседневный": ["Russian": "Повседневный", "English": "Casual", "Ukrainian": "Повсякденний", "Polish": "Codzienny", "Bokmål": "Uformell"],
        "Деловой": ["Russian": "Деловой", "English": "Business", "Ukrainian": "Діловий", "Polish": "Biznesowy", "Bokmål": "Formell"],
        "Юмористический": ["Russian": "Юмористический", "English": "Humorous", "Ukrainian": "Гумористичний", "Polish": "Humorystyczny", "Bokmål": "Humoristisk"],
        "Романтический": ["Russian": "Романтический", "English": "Romantic", "Ukrainian": "Романтичний", "Polish": "Romantyczny", "Bokmål": "Romantisk"],
        "Спор": ["Russian": "Спор", "English": "Debate", "Ukrainian": "Суперечка", "Polish": "Debata", "Bokmål": "Debatt"],
        "ИИ пишет сценарий...": ["Russian": "ИИ пишет сценарий...", "English": "AI is writing script...", "Ukrainian": "ШІ пише сценарій...", "Polish": "AI pisze scenariusz...", "Bokmål": "AI skriver manus..."],
        "Создание...": ["Russian": "Создание...", "English": "Creating...", "Ukrainian": "Створення...", "Polish": "Tworzenie...", "Bokmål": "Oppretter..."],
        // Грамматика
        "Текст для проверки": ["Russian": "Текст для проверки", "English": "Text to check", "Ukrainian": "Текст для перевірки", "Polish": "Tekst do sprawdzenia", "Bokmål": "Tekst for sjekk"],
        "AI Проверка": ["Russian": "AI Проверка", "English": "AI Check", "Ukrainian": "AI Перевірка", "Polish": "AI Sprawdzanie", "Bokmål": "AI-sjekk"],
        "Проверить грамматику": ["Russian": "Проверить грамматику", "English": "Check Grammar", "Ukrainian": "Перевірити граматику", "Polish": "Sprawdź gramatykę", "Bokmål": "Sjekk grammatikk"],
        "Режим": ["Russian": "Режим", "English": "Mode", "Ukrainian": "Режим", "Polish": "Tryb", "Bokmål": "Modus"],
        
        // Профиль и Статистика
        "Настройки": ["Russian": "Настройки", "English": "Settings", "Ukrainian": "Налаштування", "Polish": "Ustawienia", "Bokmål": "Innstillinger"],
        "Уведомления": ["Russian": "Уведомления", "English": "Notifications", "Ukrainian": "Сповіщення", "Polish": "Powiadomienia", "Bokmål": "Varsler"],
        "Родной язык": ["Russian": "Родной язык", "English": "Native Language", "Ukrainian": "Рідна мова", "Polish": "Język ojczysty", "Bokmål": "Morsmål"],
        "Снаряжение": ["Russian": "Снаряжение", "English": "Gear", "Ukrainian": "Спорядження", "Polish": "Ekwipunek", "Bokmål": "Utstyr"],
        "Твоя добыча": ["Russian": "Твоя добыча", "English": "Your Loot", "Ukrainian": "Твоя здобич", "Polish": "Twój łup", "Bokmål": "Ditt bytte"],
        "Золото": ["Russian": "Золото", "English": "Gold", "Ukrainian": "Золото", "Polish": "Złoto", "Bokmål": "Gull"],
        "Твое имя": ["Russian": "Твое имя", "English": "Your Name", "Ukrainian": "Твоє ім'я", "Polish": "Twoje imię", "Bokmål": "Ditt navn"],
        
        // --- ДИАЛОГИ И AI ПЕРСОНАЖИ ---
        "Викинг": ["Russian": "Викинг", "English": "Viking", "Ukrainian": "Вікінг", "Polish": "Wiking", "Bokmål": "Viking"],
        "Валькирия": ["Russian": "Валькирия", "English": "Valkyrie", "Ukrainian": "Валькірія", "Polish": "Valkyrie", "Bokmål": "Valkyrie"],
        "Фрейя (Мудрость & Истории)": ["Russian": "Фрейя", "English": "Freya", "Ukrainian": "Фрейя", "Polish": "Freya", "Bokmål": "Frøya"],
        "Тор (Сила & Практика)": ["Russian": "Тор", "English": "Thor", "Ukrainian": "Тор", "Polish": "Thor", "Bokmål": "Thor"],
        "Один (Знания & Руны)": ["Russian": "Один", "English": "Odin", "Ukrainian": "Одін", "Polish": "Odyn", "Bokmål": "Odin"],
        "Тон беседы": ["Russian": "Тон беседы", "English": "Tone", "Ukrainian": "Тон", "Polish": "Ton", "Bokmål": "Tone"],
        "Контекст": ["Russian": "Контекст", "English": "Context", "Ukrainian": "Контекст", "Polish": "Kontekst", "Bokmål": "Kontekst"],
        "Введи ответ...": ["Russian": "Введи ответ...", "English": "Type answer...", "Ukrainian": "Введи відповідь...", "Polish": "Wpisz odpowiedź...", "Bokmål": "Skriv svar..."],
        
        // Лавка и создание тем
        "Лавка Ярла": ["Russian": "Лавка Ярла", "English": "Jarl's Shop", "Ukrainian": "Лавка Ярла", "Polish": "Sklep Jarla", "Bokmål": "Jarlens Butikk"],
        "Купить": ["Russian": "Купить", "English": "Buy", "Ukrainian": "Купити", "Polish": "Kup", "Bokmål": "Kjøp"],
        "Выбрать": ["Russian": "Выбрать", "English": "Select", "Ukrainian": "Обрати", "Polish": "Wybierz", "Bokmål": "Velg"],
        "Выбрано": ["Russian": "Выбрано", "English": "Selected", "Ukrainian": "Обрано", "Polish": "Wybrano", "Bokmål": "Valgt"],
        "Готово": ["Russian": "Готово", "English": "Done", "Ukrainian": "Готово", "Polish": "Gotowe", "Bokmål": "Ferdig"],
        
        "Название темы": ["Russian": "Название темы", "English": "Topic Name", "Ukrainian": "Назва теми", "Polish": "Nazwa tematu", "Bokmål": "Emnenavn"],
        "Например: Рыбалка": ["Russian": "Например: Рыбалка", "English": "E.g. Fishing", "Ukrainian": "Наприклад: Риболовля", "Polish": "Np. Wędkarstwo", "Bokmål": "F.eks. Fiske"],
        "Викинг думает...": ["Russian": "Викинг думает...", "English": "Viking is thinking...", "Ukrainian": "Вікінг думає...", "Polish": "Wiking myśli...", "Bokmål": "Vikingen tenker..."],
        "Сгенерировать слова (ИИ)": ["Russian": "Сгенерировать слова (ИИ)", "English": "Generate Words (AI)", "Ukrainian": "Згенерувати слова (ШІ)", "Polish": "Generuj słowa (AI)", "Bokmål": "Generer ord (AI)"],
        "Найдено слов: ": ["Russian": "Найдено слов: ", "English": "Words found: ", "Ukrainian": "Знайдено слів: ", "Polish": "Znaleziono słów: ", "Bokmål": "Ord funnet: "],
        "Сохранить": ["Russian": "Сохранить", "English": "Save", "Ukrainian": "Зберегти", "Polish": "Zapisz", "Bokmål": "Lagre"],
        "Отмена": ["Russian": "Отмена", "English": "Cancel", "Ukrainian": "Скасувати", "Polish": "Anuluj", "Bokmål": "Avbryt"],
        "Очистить": ["Russian": "Очистить", "English": "Clear", "Ukrainian": "Очистити", "Polish": "Wyczyść", "Bokmål": "Tøm"],
        
        // --- SETTINGS (NEW) ---
        "Личное и Обучение": ["Russian": "Личное и Обучение", "English": "Personal & Learning", "Ukrainian": "Особисте та Навчання", "Polish": "Osobiste i Nauka", "Bokmål": "Personlig og Læring"],
        "Наставник": ["Russian": "Наставник", "English": "Mentor", "Ukrainian": "Наставник", "Polish": "Mentor", "Bokmål": "Mentor"],
        "Цель дня": ["Russian": "Цель дня", "English": "Daily Goal", "Ukrainian": "Ціль дня", "Polish": "Cel dzienny", "Bokmål": "Dagsmål"],
        "Атмосфера": ["Russian": "Атмосфера", "English": "Atmosphere", "Ukrainian": "Атмосфера", "Polish": "Atmosfera", "Bokmål": "Atmosfære"],
        "Напоминания": ["Russian": "Напоминания", "English": "Reminders", "Ukrainian": "Нагадування", "Polish": "Przypomnienia", "Bokmål": "Påminnelser"],
        "Время": ["Russian": "Время", "English": "Time", "Ukrainian": "Час", "Polish": "Czas", "Bokmål": "Tid"],
        "Эффекты (SFX)": ["Russian": "Эффекты (SFX)", "English": "Effects (SFX)", "Ukrainian": "Ефекти (SFX)", "Polish": "Efekty (SFX)", "Bokmål": "Effekter (SFX)"],
        "Голос озвучки": ["Russian": "Голос озвучки", "English": "Voice Gender", "Ukrainian": "Голос озвучки", "Polish": "Płeć głosu", "Bokmål": "Stemmekjønn"],
        "Скорость речи": ["Russian": "Скорость речи", "English": "Speed", "Ukrainian": "Швидкість мови", "Polish": "Prędkość mowy", "Bokmål": "No description"],
        "Данные": ["Russian": "Данные", "English": "Data", "Ukrainian": "Дані", "Polish": "Dane", "Bokmål": "Data"],
        "Статус подписки": ["Russian": "Статус подписки", "English": "Subscription Status", "Ukrainian": "Статус підписки", "Polish": "Status subskrypcji", "Bokmål": "Abonnementsstatus"],
        "Управлять подпиской": ["Russian": "Управлять подпиской", "English": "Manage Subscription", "Ukrainian": "Керувати підпискою", "Polish": "Zarządzaj subskrypcją", "Bokmål": "Administrer abonnement"],
        "Офлайн режим": ["Russian": "Офлайн режим", "English": "Offline Mode", "Ukrainian": "Офлайн режим", "Polish": "Tryb offline", "Bokmål": "Frakoblet modus"],
        "Кэш уроков": ["Russian": "Кэш уроков", "English": "Lesson Cache", "Ukrainian": "Кеш уроків", "Polish": "Pamięć lekcji", "Bokmål": "Leksjonsbuffer"],
        "Очистить кэш": ["Russian": "Очистить кэш", "English": "Clear Cache", "Ukrainian": "Очистити кеш", "Polish": "Wyczyść pamięć", "Bokmål": "Tøm buffer"],
        "Отправлять аналитику": ["Russian": "Отправлять аналитику", "English": "Share Analytics", "Ukrainian": "Відправляти аналітику", "Polish": "Udostępnij analitykę", "Bokmål": "Del analyse"],
        "Поддержка": ["Russian": "Поддержка", "English": "Support", "Ukrainian": "Підтримка", "Polish": "Wsparcie", "Bokmål": "Brukerstøtte"],
        "Сообщить о баге": ["Russian": "Сообщить о баге", "English": "Report Bug", "Ukrainian": "Повідомити про баг", "Polish": "Zgłoś błąd", "Bokmål": "Rapporter feil"],
        "Условия и Политика": ["Russian": "Условия и Политика", "English": "Terms & Privacy", "Ukrainian": "Умови та Політика", "Polish": "Warunki i Prywatność", "Bokmål": "Vilkår og Personvern"],
        "Сброс прогресса (RAGNAROK)": ["Russian": "Сброс прогресса", "English": "Reset Progress", "Ukrainian": "Скидання прогресу", "Polish": "Resetuj postęp", "Bokmål": "Tilbakestill fremgang"],
        "Удалить аккаунт": ["Russian": "Удалить аккаунт", "English": "Delete Account", "Ukrainian": "Видалити акаунт", "Polish": "Usuń konto", "Bokmål": "Slett konto"],
        "Мужской": ["Russian": "Мужской", "English": "Male", "Ukrainian": "Чоловічий", "Polish": "Męski", "Bokmål": "Mann"],
        "Женский": ["Russian": "Женский", "English": "Female", "Ukrainian": "Жіночий", "Polish": "Żeński", "Bokmål": "Kvinne"],
    
        
        // --- PRACTICE VIEW ---
        "Испытания": ["Russian": "Испытания", "English": "Challenges", "Ukrainian": "Випробування", "Polish": "Wyzwania", "Bokmål": "Utfordringer"],
        "Симуляции": ["Russian": "Симуляции", "English": "Simulations", "Ukrainian": "Симуляції", "Polish": "Symulacje", "Bokmål": "Simuleringer"],
        "Пора повторить": ["Russian": "Пора повторить", "English": "Time to Review", "Ukrainian": "Час повторити", "Polish": "Czas powtórzyć", "Bokmål": "Tid å repetere"],
        "слов": ["Russian": "слов", "English": "words", "Ukrainian": "слів", "Polish": "słów", "Bokmål": "ord"],
        "Свой сценарий": ["Russian": "Свой сценарий", "English": "Custom Scenario", "Ukrainian": "Свій сценарій", "Polish": "Własny scenariusz", "Bokmål": "Egendefinert scenario"],
        "Роль": ["Russian": "Роль", "English": "Role", "Ukrainian": "Роль", "Polish": "Rola", "Bokmål": "Rolle"],
        "Начать": ["Russian": "Начать", "English": "Start", "Ukrainian": "Почати", "Polish": "Rozpocznij", "Bokmål": "Start"],
        "Готов к походу?": ["Russian": "Готов к походу?", "English": "Ready for the journey?", "Ukrainian": "Готовий до походу?", "Polish": "Gotowy na wyprawę?", "Bokmål": "Klar for reisen?"],
        "Цели дня": ["Russian": "Цели дня", "English": "Daily Goals", "Ukrainian": "Цілі дня", "Polish": "Cele dnia", "Bokmål": "Dagens mål"],
        "Изменить": ["Russian": "Изменить", "English": "Edit", "Ukrainian": "Змінити", "Polish": "Edytuj", "Bokmål": "Rediger"],
        "Удалить": ["Russian": "Удалить", "English": "Delete", "Ukrainian": "Видалити", "Polish": "Usuń", "Bokmål": "Slett"],
        
        // --- LIBRARY VIEW ---
        "Скоро (Kommer snart)": ["Russian": "Скоро", "English": "Coming soon", "Ukrainian": "Скоро", "Polish": "Wkrótce", "Bokmål": "Kommer snart"],
        "Тест": ["Russian": "Тест", "English": "Test", "Ukrainian": "Тест", "Polish": "Test", "Bokmål": "Test"],
        "Игра": ["Russian": "Игра", "English": "Game", "Ukrainian": "Гра", "Polish": "Gra", "Bokmål": "Spill"],
        // --- БИБЛИОТЕКА: КАРТОЧКИ ---
        "Библиотека": ["Russian": "Библиотека", "English": "Library", "Ukrainian": "Бібліотека", "Polish": "Biblioteka", "Bokmål": "Bibliotek"],
                
        // Точные названия кнопок из LibraryView:
        "Новости (Live)": ["Russian": "Новости (Live)", "English": "News (Live)", "Ukrainian": "Новини (Live)", "Polish": "Wiadomości (Live)", "Bokmål": "Nyheter (Live)"],
        "Истории": ["Russian": "Истории", "English": "Stories", "Ukrainian": "Історії", "Polish": "Historie", "Bokmål": "Historier"],
        "Подкасты": ["Russian": "Подкасты", "English": "Podcasts", "Ukrainian": "Подкасти", "Polish": "Podcasty", "Bokmål": "Podkaster"],
        "Грамматика": ["Russian": "Грамматика", "English": "Grammar", "Ukrainian": "Граматика", "Polish": "Gramatyka", "Bokmål": "Grammatikk"],
                
        // Подзаголовки кнопок:
        "NRK Nynorsk": ["Russian": "NRK Nynorsk", "English": "NRK Nynorsk", "Ukrainian": "NRK Nynorsk", "Polish": "NRK Nynorsk", "Bokmål": "NRK Nynorsk"],
        "Читаем и слушаем сказки": ["Russian": "Читаем и слушаем сказки", "English": "Read and listen to tales", "Ukrainian": "Читаємо і слухаємо казки", "Polish": "Czytaj i słuchaj bajek", "Bokmål": "Les og lytt til eventyr"],
        "Диалоги и обсуждения": ["Russian": "Диалоги и обсуждения", "English": "Dialogues and discussions", "Ukrainian": "Діалоги та обговорення", "Polish": "Dialogi i dyskusje", "Bokmål": "Dialoger og diskusjoner"],
        "Справочник и проверка": ["Russian": "Справочник и проверка", "English": "Reference & Check", "Ukrainian": "Довідник та перевірка", "Polish": "Poradnik i sprawdzanie", "Bokmål": "Referanse og sjekk"],
        // Заглушки:
        "Гос. экзамен (Скоро)": ["Russian": "Гос. экзамен (Скоро)", "English": "State exam (Soon)", "Ukrainian": "Держ. іспит (Скоро)", "Polish": "Egzamin (Wkrótce)", "Bokmål": "Norskprøve (Kommer snart)"],
        "Культура": ["Russian": "Культура", "English": "Culture", "Ukrainian": "Культура", "Polish": "Kultura", "Bokmål": "Kultur"],
        "Статьи о Норвегии (Скоро)": ["Russian": "Статьи о Норвегии (Скоро)", "English": "Articles about Norway (Soon)", "Ukrainian": "Статті про Норвегію (Скоро)", "Polish": "Artykuły (Wkrótce)", "Bokmål": "Artikler (Kommer snart)"],
        
        // --- PROFILE VIEW ---
        "Боевая активность": ["Russian": "Боевая активность", "English": "Recent Activity", "Ukrainian": "Бойова активність", "Polish": "Ostatnia aktywność", "Bokmål": "Nylig aktivitet"],
        "Твоя мудрость": ["Russian": "Твоя мудрость", "English": "Your Wisdom", "Ukrainian": "Твоя мудрість", "Polish": "Twoja mądrość", "Bokmål": "Din visdom"],
        "Трофеи": ["Russian": "Трофеи", "English": "Trophies", "Ukrainian": "Трофеї", "Polish": "Trofea", "Bokmål": "Trofeer"],
        "В лавку": ["Russian": "В лавку", "English": "To Shop", "Ukrainian": "До крамниці", "Polish": "Do sklepu", "Bokmål": "Til butikken"],
        "Слов": ["Russian": "Слов", "English": "Words", "Ukrainian": "Слів", "Polish": "Słów", "Bokmål": "Ord"],
        // --- НАСТРОЙКИ: МЕЛКИЕ ДЕТАЛИ ---
        "Изм.": ["Russian": "Изм.", "English": "Edit", "Ukrainian": "Зм.", "Polish": "Edytuj", "Bokmål": "Red."],
        "мин/день": ["Russian": "мин/день", "English": "min/day", "Ukrainian": "хв/день", "Polish": "min/dzień", "Bokmål": "min/dag"],
        "Размер шрифта": ["Russian": "Размер шрифта", "English": "Font Size", "Ukrainian": "Розмір шрифту", "Polish": "Rozmiar czcionki", "Bokmål": "Skriftstørrelse"],
        "Версия": ["Russian": "Версия", "English": "Version", "Ukrainian": "Версія", "Polish": "Wersja", "Bokmål": "Versjon"],
                
        "Small": ["Russian": "Маленький", "English": "Small", "Ukrainian": "Маленький", "Polish": "Mały", "Bokmål": "Liten"],
        "Medium": ["Russian": "Средний", "English": "Medium", "Ukrainian": "Середній", "Polish": "Średni", "Bokmål": "Medium"],
        "Large": ["Russian": "Большой", "English": "Large", "Ukrainian": "Великий", "Polish": "Duży", "Bokmål": "Stor"],
        
        // --- ADD TOPIC VIEW ---
        "О чем хочешь узнать?": ["Russian": "О чем хочешь узнать?", "English": "What do you want to learn?", "Ukrainian": "Про що хочеш дізнатися?", "Polish": "O czym chcesz się dowiedzieć?", "Bokmål": "Hva vil du lære?"],
        "Сгенерировать (AI)": ["Russian": "Сгенерировать (AI)", "English": "Generate (AI)", "Ukrainian": "Згенерувати (AI)", "Polish": "Generuj (AI)", "Bokmål": "Generer (AI)"],
        "Готово! (X слов)": ["Russian": "Готово!", "English": "Done!", "Ukrainian": "Готово!", "Polish": "Gotowe!", "Bokmål": "Ferdig!"],
        "Сохранить Тему": ["Russian": "Сохранить Тему", "English": "Save Topic", "Ukrainian": "Зберегти Тему", "Polish": "Zapisz temat", "Bokmål": "Lagre emne"],
        
        // --- ONBOARDING VIEW ---
        "Подготовка...": ["Russian": "Подготовка...", "English": "Preparing...", "Ukrainian": "Підготовка...", "Polish": "Przygotowanie...", "Bokmål": "Forbereder..."],
        "Velkomen!": ["Russian": "Velkomen!", "English": "Velkomen!", "Ukrainian": "Velkomen!", "Polish": "Velkomen!", "Bokmål": "Velkomen!"],
        "Твой путь к языку фьордов начинается здесь.\nГотов ли ты к походу?": ["Russian": "Твой путь к языку фьордов начинается здесь.\\nГотов ли ты к походу?", "English": "Your journey to the language of fjords begins here.\\nAre you ready for the adventure?", "Ukrainian": "Твій шлях до мови fjordів починається тут.\\nГотовий до походу?", "Polish": "Twoja podróż do języka fiordów zaczyna się tutaj.\\nCzy jesteś gotowy?", "Bokmål": "Din reise til fjordenes språk begynner her.\\nEr du klar?"],
        "Как звать тебя, путник?": ["Russian": "Как звать тебя, путник?", "English": "What is your name, traveler?", "Ukrainian": "Як тебе звати мандрівниче?", "Polish": "Jak masz na imię, wędrowcze?", "Bokmål": "Hva heter du, reisende?"],
        "Насколько ты опытен?": ["Russian": "Насколько ты опытен?", "English": "How experienced are you?", "Ukrainian": "Наскільки ти досвідчений?", "Polish": "Jak jesteś doświadczony?", "Bokmål": "Hvor erfaren er du?"],
        "Выбери наставника": ["Russian": "Выбери наставника", "English": "Choose your mentor", "Ukrainian": "Обери наставника", "Polish": "Wybierz mentora", "Bokmål": "Velg mentor"],
        "Свайпай, чтобы выбрать": ["Russian": "Свайпай, чтобы выбрать", "English": "Swipe to choose", "Ukrainian": "Свайпай, щоб обрати", "Polish": "Przesuń, aby wybrać", "Bokmål": "Sveip for å velge"],
        
        // --- COMMON / MISC ---
        "OK": ["Russian": "OK", "English": "OK", "Ukrainian": "OK", "Polish": "OK", "Bokmål": "OK"],
        "Далее": ["Russian": "Далее", "English": "Next", "Ukrainian": "Далі", "Polish": "Dalej", "Bokmål": "Neste"],
        "Назад": ["Russian": "Назад", "English": "Back", "Ukrainian": "Назад", "Polish": "Wstecz", "Bokmål": "Tilbake"],
        "Загрузка...": ["Russian": "Загрузка...", "English": "Loading...", "Ukrainian": "Завантаження...", "Polish": "Ładowanie...", "Bokmål": "Laster..."],
        
        // --- STATISTICS / CHARTS ---
        "Выучено": ["Russian": "Выучено", "English": "Mastered", "Ukrainian": "Вивчено", "Polish": "Opanowane", "Bokmål": "Mestret"],
        "В процессе": ["Russian": "В процессе", "English": "Learning", "Ukrainian": "В процесі", "Polish": "W trakcie", "Bokmål": "Lærer"],
        "Новые": ["Russian": "Новые", "English": "New", "Ukrainian": "Нові", "Polish": "Nowe", "Bokmål": "Nye"],
        "Стрик": ["Russian": "Стрик", "English": "Streak", "Ukrainian": "Стрік", "Polish": "Seria", "Bokmål": "Streak"],
        "Всего XP": ["Russian": "Всего XP", "English": "Total XP", "Ukrainian": "Всього XP", "Polish": "Razem XP", "Bokmål": "Total XP"],
        "дн": ["Russian": "дн", "English": "d", "Ukrainian": "дн", "Polish": "dni", "Bokmål": "d"],
        
        // --- SHOP VIEW ---
        "Доступно": ["Russian": "Доступно", "English": "Available", "Ukrainian": "Доступно", "Polish": "Dostępne", "Bokmål": "Tilgjengelig"],
        "Куплено": ["Russian": "Куплено", "English": "Purchased", "Ukrainian": "Куплено", "Polish": "Kupione", "Bokmål": "Kjøpt"],
        "Надеть": ["Russian": "Надеть", "English": "Equip", "Ukrainian": "Надіти", "Polish": "Załóż", "Bokmål": "Ta på"],
        "Снаряжено": ["Russian": "Снаряжено", "English": "Equipped", "Ukrainian": "Споряджено", "Polish": "Założone", "Bokmål": "Utstyrt"],
        
        // --- ADD TOPIC DIALOG ---
        "Добавить тему": ["Russian": "Добавить тему", "English": "Add Topic", "Ukrainian": "Додати тему", "Polish": "Dodaj temat", "Bokmål": "Legg til emne"],
        "Иконка": ["Russian": "Иконка", "English": "Icon", "Ukrainian": "Іконка", "Polish": "Ikona", "Bokmål": "Ikon"],
        "Уровень": ["Russian": "Уровень", "English": "Level", "Ukrainian": "Рівень", "Polish": "Poziom", "Bokmål": "Nivå"],
        
        // --- STORIES & PODCASTS ---
        "Пока пусто": ["Russian": "Пока пусто", "English": "Nothing here yet", "Ukrainian": "Поки пусто", "Polish": "Jeszcze pusto", "Bokmål": "Ingenting her ennå"],
        "Сгенерируй свою первую историю на Nynorsk.": ["Russian": "Сгенерируй свою первую историю на Nynorsk.", "English": "Generate your first story in Nynorsk.", "Ukrainian": "Згенеруй свою першу історію Nynorsk.", "Polish": "Wygeneruj swoją pierwszą historię w Nynorsk.", "Bokmål": "Generer din første historie på Nynorsk."],
        "Сгенерируй свой первый подкаст на Nynorsk.": ["Russian": "Сгенерируй свой первый подкаст на Nynorsk.", "English": "Generate your first podcast in Nynorsk.", "Ukrainian": "Згенеруй свій перший подкаст Nynorsk.", "Polish": "Wygeneruj swój pierwszy podcast w Nynorsk.", "Bokmål": "Generer din første podcast på Nynorsk."],
        "Твой кошель:": ["Russian": "Твой кошель:", "English": "Your wallet:", "Ukrainian": "Твій гаманець:", "Polish": "Twój portfel:", "Bokmål": "Din lommebok:"],
        
        // --- QUIZ & EXAM ---
        "Мало слов": ["Russian": "Мало слов", "English": "Too few words", "Ukrainian": "Мало слів", "Polish": "Za mało słów", "Bokmål": "For få ord"],
        "Нужно минимум 4 слова для игры.": ["Russian": "Нужно минимум 4 слова для игры.", "English": "Need at least 4 words to play.", "Ukrainian": "Потрібно мінімум 4 слова для гри.", "Polish": "Potrzebujesz co najmniej 4 słów do gry.", "Bokmål": "Trenger minst 4 ord for å spille."],
        "Игра окончена": ["Russian": "Игра окончена", "English": "Game Over", "Ukrainian": "Гра закінчена", "Polish": "Koniec gry", "Bokmål": "Spillet er over"],
        "Твой счет:": ["Russian": "Твой счет:", "English": "Your score:", "Ukrainian": "Твій рахунок:", "Polish": "Twój wynik:", "Bokmål": "Din poengsum:"],
        "сек": ["Russian": "сек", "English": "sec", "Ukrainian": "сек", "Polish": "sek", "Bokmål": "sek"],
        "Вопрос": ["Russian": "Вопрос", "English": "Question", "Ukrainian": "Питання", "Polish": "Pytanie", "Bokmål": "Spørsmål"],
        "Правильно:": ["Russian": "Правильно:", "English": "Correct:", "Ukrainian": "Правильно:", "Polish": "Poprawnie:", "Bokmål": "Riktig:"],
        "из": ["Russian": "из", "English": "of", "Ukrainian": "з", "Polish": "z", "Bokmål": "av"],
        
        // --- STUDY SESSION ---
        "В этой теме пока нет слов для повторения.": ["Russian": "В этой теме пока нет слов для повторения.", "English": "No words to review in this topic yet.", "Ukrainian": "У цій темі поки немає слів для повторення.", "Polish": "W tym temacie nie ma jeszcze słów do powtórki.", "Bokmål": "Ingen ord å repetere i dette emnet ennå."],
        "Осталось:": ["Russian": "Осталось:", "English": "Remaining:", "Ukrainian": "Залишилось:", "Polish": "Pozostało:", "Bokmål": "Gjenstår:"],
        "Урок окончен!": ["Russian": "Урок окончен!", "English": "Lesson Complete!", "Ukrainian": "Урок закінчено!", "Polish": "Lekcja ukończona!", "Bokmål": "Leksjon fullført!"],
        "Слова закончились": ["Russian": "Слова закончились", "English": "No more words", "Ukrainian": "Слова закінчились", "Polish": "Brak więcej słów", "Bokmål": "Ingen flere ord"],
        "Сессия завершена!": ["Russian": "Сессия завершена!", "English": "Session Complete!", "Ukrainian": "Сесія завершена!", "Polish": "Sesja zakończona!", "Bokmål": "Økt fullført!"],
        
        // --- DAILY WORD ---
        "Слово дня": ["Russian": "Слово дня", "English": "Word of the Day", "Ukrainian": "Слово дня", "Polish": "Słowo dnia", "Bokmål": "Dagens ord"],
        "Нажми, чтобы узнать": ["Russian": "Нажми, чтобы узнать", "English": "Tap to reveal", "Ukrainian": "Натисни, щоб дізнатися", "Polish": "Dotknij, aby poznać", "Bokmål": "Trykk for å avsløre"],
        "Добавьте слова в словарь, чтобы увидеть слово дня!": ["Russian": "Добавьте слова в словарь, чтобы увидеть слово дня!", "English": "Add words to see the word of the day!", "Ukrainian": "Додайте слова, щоб побачити слово дня!", "Polish": "Dodaj słowa, aby zobaczyć słowo dnia!", "Bokmål": "Legg til ord for å se dagens ord!"],
        
        // --- EDIT TOPIC ---
        "Нет слов. Добавьте первое!": ["Russian": "Нет слов. Добавьте первое!", "English": "No words. Add the first one!", "Ukrainian": "Немає слів. Додайте перше!", "Polish": "Brak słów. Dodaj pierwsze!", "Bokmål": "Ingen ord. Legg til det første!"],
        
        // --- GRAMMAR & IMPORT ---
        "Справочник": ["Russian": "Справочник", "English": "Reference", "Ukrainian": "Довідник", "Polish": "Poradnik", "Bokmål": "Referanse"],
        "Результат:": ["Russian": "Результат:", "English": "Result:", "Ukrainian": "Результат:", "Polish": "Wynik:", "Bokmål": "Resultat:"],
        "Текст (Nynorsk)": ["Russian": "Текст (Nynorsk)", "English": "Text (Nynorsk)", "Ukrainian": "Текст (Nynorsk)", "Polish": "Tekst (Nynorsk)", "Bokmål": "Tekst (Nynorsk)"],
        
        // --- GENERATORS ---
        "ИИ пишет историю...": ["Russian": "ИИ пишет историю...", "English": "AI is writing story...", "Ukrainian": "ШІ пише історію...", "Polish": "AI pisze historię...", "Bokmål": "AI skriver historie..."],
        "Сгенерировать (5 монет)": ["Russian": "Сгенерировать (5 монет)", "English": "Generate (5 coins)", "Ukrainian": "Згенерувати (5 монет)", "Polish": "Generuj (5 monet)", "Bokmål": "Generer (5 mynter)"],
        "Сгенерировать (10 монет)": ["Russian": "Сгенерировать (10 монет)", "English": "Generate (10 coins)", "Ukrainian": "Згенерувати (10 монет)", "Polish": "Generuj (10 monet)", "Bokmål": "Generer (10 mynter)"],
        
        // --- WORD LIST ---
        "Начать урок": ["Russian": "Начать урок", "English": "Start Lesson", "Ukrainian": "Почати урок", "Polish": "Rozpocznij lekcję", "Bokmål": "Start leksjon"],
        "Пусто": ["Russian": "Пусто", "English": "Empty", "Ukrainian": "Пусто", "Polish": "Puste", "Bokmål": "Tom"],
        "Добавьте слова (+)": ["Russian": "Добавьте слова (+)", "English": "Add words (+)", "Ukrainian": "Додайте слова (+)", "Polish": "Dodaj słowa (+)", "Bokmål": "Legg til ord (+)"],
        
        // --- РЕДАКТИРОВАНИЕ ТЕМЫ (НОВОЕ) ---
        "Редактирование": ["Russian": "Редактирование", "English": "Edit Topic", "Ukrainian": "Редагування", "Polish": "Edycja", "Bokmål": "Redigering"],
        "О теме": ["Russian": "О теме", "English": "About Topic", "Ukrainian": "Про тему", "Polish": "O temacie", "Bokmål": "Om emnet"],
        "Цвет оформления": ["Russian": "Цвет оформления", "English": "Theme Color", "Ukrainian": "Колір теми", "Polish": "Kolor motywu", "Bokmål": "Temafarge"],
        "Добавить слово": ["Russian": "Добавить слово", "English": "Add Word", "Ukrainian": "Додати слово", "Polish": "Dodaj słowo", "Bokmål": "Legg til ord"],
                
        "Новое слово": ["Russian": "Новое слово", "English": "New Word", "Ukrainian": "Нове слово", "Polish": "Nowe słowo", "Bokmål": "Nytt ord"],
        "Добавление слова": ["Russian": "Добавление слова", "English": "Adding a word", "Ukrainian": "Додавання слова", "Polish": "Dodawanie słowa", "Bokmål": "Legger til ord"],
        "На родном (напр. Племянница)": ["Russian": "На родном (напр. Дом)", "English": "In native (e.g. House)", "Ukrainian": "Рідною (напр. Дім)", "Polish": "W ojczystym (np. Dom)", "Bokmål": "På morsmål (f.eks. Hus)"],
        "Изменить слово": ["Russian": "Изменить слово", "English": "Edit Word", "Ukrainian": "Змінити слово", "Polish": "Edytuj słowo", "Bokmål": "Rediger ord"],
        "Перевод": ["Russian": "Перевод", "English": "Translation", "Ukrainian": "Переклад", "Polish": "Tłumaczenie", "Bokmål": "Oversettelse"],
        
        // --- ОНБОРДИНГ (ТОЧНЫЕ КЛЮЧИ) ---
        "Начать поход ⚔️": ["Russian": "Начать поход ⚔️", "English": "Start Journey ⚔️", "Ukrainian": "Почати похід ⚔️", "Polish": "Rozpocznij podróż ⚔️", "Bokmål": "Start reisen ⚔️"],
        "Введи свое имя": ["Russian": "Введи свое имя", "English": "Enter your name", "Ukrainian": "Введи своє ім'я", "Polish": "Wpisz swoje imię", "Bokmål": "Skriv inn navnet ditt"],
                
        // Ранги (Ключи совпадают с кодом в OnboardingView)
        "Thrall (Новичок)": ["Russian": "Трэлл (Новичок)", "English": "Thrall (Novice)", "Ukrainian": "Трелл (Новачок)", "Polish": "Thrall (Nowicjusz)", "Bokmål": "Trell (Nykommer)"],
        "Krigar (Воин)": ["Russian": "Кригар (Воин)", "English": "Krigar (Warrior)", "Ukrainian": "Крігар (Воїн)", "Polish": "Krigar (Wojownik)", "Bokmål": "Krigar (Kriger)"],
        "Jarl (Ярл)": ["Russian": "Ярл (Вождь)", "English": "Jarl (Chieftain)", "Ukrainian": "Ярл (Вождь)", "Polish": "Jarl (Wódz)", "Bokmål": "Jarl (Høvding)"],
                
        // Описания рангов
        "Я только ступил на этот берег": ["Russian": "Я только ступил на этот берег", "English": "I just stepped on this shore", "Ukrainian": "Я тільки ступив на цей берег", "Polish": "Dopiero stanąłem na tym brzegu", "Bokmål": "Jeg har nettopp gått i land"],
        "Я уже держал меч в руках": ["Russian": "Я уже держал меч в руках", "English": "I have held a sword before", "Ukrainian": "Я вже тримав меч у руках", "Polish": "Trzymałem już miecz", "Bokmål": "Jeg har holdt et sverd før"],
        "Я говорю как скальд": ["Russian": "Я говорю как скальд", "English": "I speak like a skald", "Ukrainian": "Я говорю як скальд", "Polish": "Mówię jak skald", "Bokmål": "Jeg snakker som en skald"],
                
        // Наставники
        "Фрейя (Freya)": ["Russian": "Фрейя (Freya)", "English": "Freya", "Ukrainian": "Фрейя", "Polish": "Freya", "Bokmål": "Frøya"],
        "Тор (Thor)": ["Russian": "Тор (Thor)", "English": "Thor", "Ukrainian": "Тор", "Polish": "Thor", "Bokmål": "Thor"],
        "Один (Odin)": ["Russian": "Один (Odin)", "English": "Odin", "Ukrainian": "Одін", "Polish": "Odyn", "Bokmål": "Odin"],
                
        "Для тех, кто хочет расслабиться.": ["Russian": "Для тех, кто хочет расслабиться.", "English": "For those who want to relax.", "Ukrainian": "Для тих, хто хоче розслабитися.", "Polish": "Dla tych, którzy chcą się zrelaksować.", "Bokmål": "For de som vil slappe av."],
        "Для тех, кто любит хардкор.": ["Russian": "Для тех, кто любит хардкор.", "English": "For those who love hardcore.", "Ukrainian": "Для тих, хто любить хардкор.", "Polish": "Dla tych, którzy kochają hardcore.", "Bokmål": "For de som elsker hardcore."],
        "Для глубокого погружения.": ["Russian": "Для глубокого погружения.", "English": "For deep immersion.", "Ukrainian": "Для глибокого занурення.", "Polish": "Dla głębokiego zanurzenia.", "Bokmål": "For dyp fordypning."],
                
        "Мягкий подход. Мы будем учить через красивые истории и культуру.": ["Russian": "Мягкий подход.", "English": "Gentle approach.", "Ukrainian": "М'який підхід.", "Polish": "Łagodne podejście.", "Bokmål": "Myk tilnærming."],
        "Сила и дисциплина! Грамматика, четкие правила, никакой пощады!": ["Russian": "Сила и дисциплина!", "English": "Strength and discipline!", "Ukrainian": "Сила і дисципліна!", "Polish": "Siła i dyscyplina!", "Bokmål": "Styrke og disiplin!"],
        "Мудрость. Редкие слова, этимология и древние руны.": ["Russian": "Мудрость.", "English": "Wisdom.", "Ukrainian": "Мудрість.", "Polish": "Mądrość.", "Bokmål": "Visdom."],
        
        // --- НОВЫЕ ТЕМЫ И ГРАММАТИКА ---
        "Mimers Brønn": ["Russian": "Колодец Мимира", "English": "Mimir's Well", "Ukrainian": "Колодязь Міміра", "Polish": "Studnia Mimira", "Bokmål": "Mimers Brønn"],
        "Существительные (Substantiv)": ["Russian": "Существительные", "English": "Nouns", "Ukrainian": "Іменники", "Polish": "Rzeczowniki", "Bokmål": "Substantiv"],
        "Местоимения (Pronomen)": ["Russian": "Местоимения", "English": "Pronouns", "Ukrainian": "Займенники", "Polish": "Zaimki", "Bokmål": "Pronomen"],
        "Отрицание (Ikkje)": ["Russian": "Отрицание (Ikkje)", "English": "Negation (Ikkje)", "Ukrainian": "Заперечення (Ikkje)", "Polish": "Przeczenie (Ikkje)", "Bokmål": "Negasjon (Ikkje)"],
  
        // --- АЛЕРТЫ НАСТРОЕК ---
        "Имя": ["Russian": "Имя", "English": "Name", "Ukrainian": "Ім'я", "Polish": "Imię", "Bokmål": "Navn"],
        "Как к тебе обращаться?": ["Russian": "Как к тебе обращаться?", "English": "What should we call you?", "Ukrainian": "Як до тебе звертатися?", "Polish": "Jak się do ciebie zwracać?", "Bokmål": "Hva skal vi kalle deg?"],
        "Рагнарёк (Сброс)": ["Russian": "Рагнарёк (Сброс)", "English": "Ragnarok (Reset)", "Ukrainian": "Рагнарок (Скидання)", "Polish": "Ragnarok (Reset)", "Bokmål": "Ragnarok (Tilbakestill)"],
        "Сжечь всё": ["Russian": "Сжечь всё", "English": "Burn everything", "Ukrainian": "Спалити все", "Polish": "Spal wszystko", "Bokmål": "Brenn alt"],
        "Весь прогресс будет потерян. Вы начнете как новый викинг.": ["Russian": "Весь прогресс будет потерян. Вы начнете как новый викинг.", "English": "All progress will be lost. You will start as a new Viking.", "Ukrainian": "Весь прогрес буде втрачено.", "Polish": "Cały postęp zostanie utracony.", "Bokmål": "All fremgang vil gå tapt."],
        "Удаление аккаунта": ["Russian": "Удаление аккаунта", "English": "Delete Account", "Ukrainian": "Видалення акаунту", "Polish": "Usuń konto", "Bokmål": "Slett konto"],
        "Это действие необратимо удалит ваши данные с наших серверов.": ["Russian": "Это действие необратимо удалит ваши данные.", "English": "This action will permanently delete your data.", "Ukrainian": "Ця дія безповоротно видалить ваші дані.", "Polish": "Ta czynność trwale usunie Twoje dane.", "Bokmål": "Denne handlingen vil slette dataene dine permanent."],
        "Напиши 'Ragnarok', чтобы подтвердить удаление всего прогресса.": ["Russian": "Напиши 'Ragnarok' для подтверждения.", "English": "Type 'Ragnarok' to confirm reset."],
        
        
        // --- ЧИТАЛКА И СЛОВАРЬ (ReaderView) ---
                "Чтение": ["Russian": "Чтение", "English": "Reading", "Ukrainian": "Читання", "Polish": "Czytanie", "Bokmål": "Lesing"],
                "Завершить чтение": ["Russian": "Завершить чтение", "English": "Finish Reading", "Ukrainian": "Завершити читання", "Polish": "Zakończ czytanie", "Bokmål": "Fullfør lesing"],
                "Читать полностью (NRK.no)": ["Russian": "Читать полностью (NRK.no)", "English": "Read full (NRK.no)", "Ukrainian": "Читати повністю (NRK.no)", "Polish": "Czytaj całość (NRK.no)", "Bokmål": "Les hele (NRK.no)"],
                
                // Всплывающее окно словаря
        "Слово": ["Russian": "Слово", "English": "Word", "Ukrainian": "Слово", "Polish": "Słowo", "Bokmål": "Ord"],
        "Закрыть": ["Russian": "Закрыть", "English": "Close", "Ukrainian": "Закрити", "Polish": "Zamknij", "Bokmål": "Lukk"],
        "Слово уже сохранено": ["Russian": "Слово уже сохранено", "English": "Word already saved", "Ukrainian": "Слово вже збережено", "Polish": "Słowo już zapisane", "Bokmål": "Ord allerede lagret"],
        "Статус": ["Russian": "Статус", "English": "Status", "Ukrainian": "Статус", "Polish": "Status", "Bokmål": "Status"],
        "Род": ["Russian": "Род", "English": "Gender", "Ukrainian": "Рід", "Polish": "Rodzaj", "Bokmål": "Kjønn"],
        "Сохранить в": ["Russian": "Сохранить в", "English": "Save to", "Ukrainian": "Зберегти в", "Polish": "Zapisz w", "Bokmål": "Lagre i"],
        "Перевести (AI)": ["Russian": "Перевести (AI)", "English": "Translate (AI)", "Ukrainian": "Перекласти (AI)", "Polish": "Przetłumacz (AI)", "Bokmål": "Oversett (AI)"],
        "AI ищет перевод...": ["Russian": "AI ищет перевод...", "English": "AI is translating...", "Ukrainian": "AI шукає переклад...", "Polish": "AI tłumaczy...", "Bokmål": "AI oversetter..."],
        "Ошибка перевода": ["Russian": "Ошибка перевода", "English": "Translation error", "Ukrainian": "Помилка перекладу", "Polish": "Błąd tłumaczenia", "Bokmål": "Oversettelsesfeil"],
        
        // --- ГРАММАТИКА (ПОЛЬЗОВАТЕЛЬСКАЯ) ---
        "Здесь пусто. Добавь фото правил или заметки.": ["Russian": "Здесь пусто. Добавь фото или заметки.", "English": "It's empty. Add photos or notes.", "Ukrainian": "Тут порожньо. Додай фото або нотатки.", "Polish": "Pusto. Dodaj zdjęcia lub notatki.", "Bokmål": "Det er tomt. Legg til bilder eller notater."],
        // --- ГРАММАТИКА: НОВЫЙ ДИЗАЙН ---
        "Мой справочник": ["Russian": "Мой справочник", "English": "My Reference", "Ukrainian": "Мій довідник", "Polish": "Mój poradnik", "Bokmål": "Min referanse"],
        "Добавь свои правила, фото таблиц или заметки.": ["Russian": "Добавь свои правила, фото таблиц или заметки.", "English": "Add your rules, photos or notes.", "Ukrainian": "Додай свої правила, фото або нотатки.", "Polish": "Dodaj swoje zasady, zdjęcia lub notatki.", "Bokmål": "Legg til dine regler, bilder eller notater."],
        "Полезные ресурсы (Web)": ["Russian": "Полезные ресурсы (Web)", "English": "Useful Resources (Web)", "Ukrainian": "Корисні ресурси (Web)", "Polish": "Przydatne zasoby (Web)", "Bokmål": "Nyttige ressurser (Web)"],
                
                // Форма добавления
        "Новая запись": ["Russian": "Новая запись", "English": "New Entry", "Ukrainian": "Новий запис", "Polish": "Nowy wpis", "Bokmål": "Ny oppføring"],
        "Заголовок": ["Russian": "Заголовок", "English": "Title", "Ukrainian": "Заголовок", "Polish": "Tytuł", "Bokmål": "Tittel"],
        "Например: Таблица глаголов": ["Russian": "Например: Таблица глаголов", "English": "E.g. Verb Table", "Ukrainian": "Наприклад: Таблиця дієслів", "Polish": "Np. Tabela czasowników", "Bokmål": "F.eks. Verbtabell"],
        "Фото (Опционально)": ["Russian": "Фото (Опционально)", "English": "Photo (Optional)", "Ukrainian": "Фото (Необов'язково)", "Polish": "Zdjęcie (Opcjonalne)", "Bokmål": "Bilde (Valgfritt)"],
            "Заметка": ["Russian": "Заметка", "English": "Note", "Ukrainian": "Нотатка", "Polish": "Notatka", "Bokmål": "Notat"],
        "Сюда можно вставить текст правила или комментарий": ["Russian": "Текст правила или комментарий", "English": "Rule text or comment", "Ukrainian": "Текст правила або коментар", "Polish": "Tekst zasady lub komentarz", "Bokmål": "Regeltekst eller kommentar"],
                
                // Описания ресурсов
        "Таблицы правил (PDF)": ["Russian": "Таблицы правил (PDF)", "English": "Rule Tables (PDF)", "Ukrainian": "Таблиці правил (PDF)", "Polish": "Tabele zasad (PDF)", "Bokmål": "Regeltabeller (PDF)"],
        "Официальный словарь": ["Russian": "Официальный словарь", "English": "Official Dictionary", "Ukrainian": "Офіційний словник", "Polish": "Oficjalny słownik", "Bokmål": "Offisiell ordbok"],
        "Языковой совет (Правила)": ["Russian": "Языковой совет (Правила)", "English": "Language Council (Rules)", "Ukrainian": "Мовна рада (Правила)", "Polish": "Rada Językowa (Zasady)", "Bokmål": "Språkrådet (Regler)"],
        "Ресурсы для обучения": ["Russian": "Ресурсы для обучения", "English": "Learning Resources", "Ukrainian": "Ресурси для навчання", "Polish": "Zasoby do nauki", "Bokmål": "Læringsressurser"],
        "Школьные материалы": ["Russian": "Школьные материалы", "English": "School Materials", "Ukrainian": "Шкільні матеріали", "Polish": "Materiały szkolne", "Bokmål": "Skolemateriell"],
    ]
    
    // Переводы названий тем (для контента)
        private let topicTranslations: [String: [String: String]] = [
            // --- Nynorsk Keys (Оригиналы) ---
            "Alfabetet": ["Russian": "Алфавит", "English": "Alphabet", "Ukrainian": "Алфавіт", "Polish": "Alfabet", "Bokmål": "Alfabetet"],
            "Tall": ["Russian": "Числа", "English": "Numbers", "Ukrainian": "Числа", "Polish": "Liczby", "Bokmål": "Tall"],
            "Fargar": ["Russian": "Цвета", "English": "Colors", "Ukrainian": "Кольори", "Polish": "Kolory", "Bokmål": "Farger"],
            "Familie": ["Russian": "Семья", "English": "Family", "Ukrainian": "Сім'я", "Polish": "Rodzina", "Bokmål": "Familie"],
            "Mat": ["Russian": "Еда", "English": "Food", "Ukrainian": "Їжа", "Polish": "Jedzenie", "Bokmål": "Mat"],
            "Jobb": ["Russian": "Работа", "English": "Job", "Ukrainian": "Робота", "Polish": "Praca", "Bokmål": "Jobb"],
            "Samfunn": ["Russian": "Общество", "English": "Society", "Ukrainian": "Суспільство", "Polish": "Społeczeństwo", "Bokmål": "Samfunn"],
            "Helsing": ["Russian": "Приветствия", "English": "Greetings", "Ukrainian": "Привітання", "Polish": "Hilsener", "Bokmål": "Hilsener"],
            "Natur": ["Russian": "Природа", "English": "Nature", "Ukrainian": "Природа", "Polish": "Natur", "Bokmål": "Natur"],
                    
            // --- English Keys (Алиасы - для починки старых баз данных) ---
            "Alphabet": ["Russian": "Алфавит", "English": "Alphabet", "Ukrainian": "Алфавіт", "Polish": "Alfabet", "Bokmål": "Alfabetet"],
            "Numbers": ["Russian": "Числа", "English": "Numbers", "Ukrainian": "Числа", "Polish": "Liczby", "Bokmål": "Tall"],
            "Colors": ["Russian": "Цвета", "English": "Colors", "Ukrainian": "Кольори", "Polish": "Kolory", "Bokmål": "Farger"],
            "Family": ["Russian": "Семья", "English": "Family", "Ukrainian": "Сім'я", "Polish": "Rodzina", "Bokmål": "Familie"],
            "Food": ["Russian": "Еда", "English": "Food", "Ukrainian": "Їжа", "Polish": "Jedzenie", "Bokmål": "Mat"],
            "Job": ["Russian": "Работа", "English": "Job", "Ukrainian": "Робота", "Polish": "Praca", "Bokmål": "Jobb"],
            "Society": ["Russian": "Общество", "English": "Society", "Ukrainian": "Суспільство", "Polish": "Społeczeństwo", "Bokmål": "Samfunn"],
            "Greetings": ["Russian": "Приветствия", "English": "Greetings", "Ukrainian": "Привітання", "Polish": "Hilsener", "Bokmål": "Hilsener"],
            "Nature": ["Russian": "Природа", "English": "Nature", "Ukrainian": "Природа", "Polish": "Natur", "Bokmål": "Natur"]
                ]
    
    
    // Главная функция перевода
    func t(_ key: String) -> String {
        return uiTranslations[key]?[currentLanguage] ?? key
    }
    
    func localizeTopicName(_ originalName: String) -> String {
            // 1. Очищаем имя от старых скобок (берем только первую часть до скобки)
            let cleanName = originalName.components(separatedBy: " (").first ?? originalName
            
            // 2. Ищем перевод для текущего языка
            if let translatedWord = topicTranslations[cleanName]?[currentLanguage] {
                return translatedWord // Возвращаем ТОЛЬКО перевод (например: "Привітання")
            }
            
            // 3. Если перевода нет — возвращаем чистое оригинальное название (например: "Helsing")
            return cleanName
        }
}

// Расширение для удобства
extension String {
    var localized: String {
        LocalizationManager.shared.t(self)
    }
}
