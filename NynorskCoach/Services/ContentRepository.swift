import Foundation

class ContentRepository {
    
    // --- Helper Functions ---
    
    private static func parseGender(_ pos: String) -> GrammaticalGender {
        let p = pos.lowercased().trimmingCharacters(in: .whitespaces)
        if p == "m" || p.contains("m ") { return .masculine }
        if p == "f" || p.contains("f ") { return .feminine }
        if p == "n" || p.contains("n ") { return .neuter }
        return .none
    }
    
    private static func w(_ no: String, _ ru: String, _ pos: String, _ ctx: String, _ ctxRu: String) -> PresetWord {
        PresetWord(
            nynorsk: no,
            translations: ["Russian": ru, "English": "?"],
            gender: parseGender(pos),
            context: ctx,
            contextTrans: ["Russian": ctxRu]
        )
    }
    
    // MARK: - DATABASE
    
    static var allPresets: [PresetTopic] {
        [
            // MARK: --- LEVEL A0 ---
            
            PresetTopic(
                id: "a0_theme1",
                nynorskTitle: "Person og identitet",
                translations: ["Russian": "Личность и данные", "English": "Person & Identity"],
                emoji: "person.text.rectangle.fill",
                difficulty: "A0",
                color: "blue",
                words: [
                    w("Eg", "Я", "pron", "Eg heiter Anna", "Меня зовут Анна"),
                    w("Du", "Ты", "pron", "Bur du her?", "Ты живешь здесь?"),
                    w("Han", "Он", "pron", "Han kjem frå Noreg", "Он из Норвегии"),
                    w("Ho", "Она", "pron", "Ho er lærar", "Она учитель"),
                    w("Vi", "Мы", "pron", "Vi snakkar nynorsk", "Мы говорим на нюнорске"),
                    w("Heite", "Называться (зваться)", "v", "Kva heiter du?", "Как тебя зовут?"),
                    w("Kome", "Приходить/Приезжать", "v", "Eg kjem frå Ukraina", "Я (родом) из Украины"),
                    w("Bu", "Жить (проживать)", "v", "Kvar bur du?", "Где ты живешь?"),
                    w("Namn", "Имя", "n", "Mitt namn er Ola", "Мое имя Ула"),
                    w("Land", "Страна", "n", "Noreg er eit langt land", "Норвегия — длинная страна"),
                    w("Språk", "Язык", "n", "Kva språk snakkar du?", "На каком языке ты говоришь?")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme2",
                nynorskTitle: "Høflegheit og kontakt",
                translations: ["Russian": "Вежливость и контакт", "English": "Politeness"],
                emoji: "hand.wave.fill",
                difficulty: "A0",
                color: "cyan",
                words: [
                    w("Hei", "Привет", "interj", "Hei, korleis går det?", "Привет, как дела?"),
                    w("God morgon", "Доброе утро", "frase", "God morgon, sov du godt?", "Доброе утро, ты хорошо спал?"),
                    w("Ha det", "Пока (до свидания)", "frase", "Ha det bra!", "Всего хорошего! (Пока!)"),
                    w("Takk", "Спасибо", "interj", "Takk for maten", "Спасибо за еду"),
                    w("Unnskyld", "Извини(те)", "interj", "Unnskyld, eg forstår ikkje", "Извините, я не понимаю"),
                    w("Ja", "Да", "adv", "Ja, eg vil gjerne ha kaffi", "Да, я бы хотел кофе"),
                    w("Nei", "Нет", "adv", "Nei, eg likar ikkje fisk", "Нет, мне не нравится рыба"),
                    w("Bra", "Хорошо", "adj", "Det går bra", "Дела идут хорошо"),
                    w("Hyggjeleg", "Приятный/Приятно", "adj", "Hyggjeleg å helse på deg", "Приятно познакомиться")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme3",
                nynorskTitle: "Tal og tid",
                translations: ["Russian": "Числа и время", "English": "Numbers & Time"],
                emoji: "clock.fill",
                difficulty: "A0",
                color: "mint",
                words: [
                    w("Ein", "Один", "num", "Eg har ein bror", "У меня есть один брат"),
                    w("To", "Два", "num", "Klokka er to", "Сейчас два часа"),
                    w("Tre", "Три", "num", "Det er tre bilar der", "Там три машины"),
                    w("Klokke", "Часы/Время", "f", "Kva er klokka?", "Сколько времени?"),
                    w("Tid", "Время", "f", "Har du tid?", "У тебя есть время?"),
                    w("Dag", "День", "m", "Ein dag har 24 timar", "В дне 24 часа"),
                    w("Natt", "Ночь", "f", "God natt", "Спокойной ночи"),
                    w("Veke", "Неделя", "f", "Det er sju dagar i ei veke", "В неделе семь дней"),
                    w("År", "Год", "n", "Eg er tjue år", "Мне двадцать лет"),
                    w("Nå", "Сейчас", "adv", "Kva gjer du nå?", "Что ты делаешь сейчас?")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme4",
                nynorskTitle: "Grunnleggande verb",
                translations: ["Russian": "Базовые глаголы", "English": "Basic Verbs"],
                emoji: "figure.run",
                difficulty: "A0",
                color: "indigo",
                words: [
                    w("Vere", "Быть", "v", "Eg er glad", "Я рад"),
                    w("Ha", "Иметь", "v", "Har du pengar?", "У тебя есть деньги?"),
                    w("Gjere", "Делать", "v", "Kva gjer du?", "Что ты делаешь?"),
                    w("Sjå", "Смотреть/Видеть", "v", "Eg ser deg", "Я тебя вижу"),
                    w("Høyre", "Слышать", "v", "Høyrer du kva eg seier?", "Ты слышишь, что я говорю?"),
                    w("Ete", "Есть (кушать)", "v", "Eg et brød", "Я ем хлеб"),
                    w("Drikke", "Пить", "v", "Eg drikk vatn", "Я пью воду"),
                    w("Sove", "Спать", "v", "Barnet søv", "Ребенок спит"),
                    w("Gå", "Идти/Ходить", "v", "Vi går på tur", "Мы идем гулять"),
                    w("Forstå", "Понимать", "v", "Forstår du nynorsk?", "Ты понимаешь нюнорск?")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme5",
                nynorskTitle: "Stad og kvardag",
                translations: ["Russian": "Места и будни", "English": "Places"],
                emoji: "map.fill",
                difficulty: "A0",
                color: "brown",
                words: [
                    w("Hus", "Дом", "n", "Huset er raudt", "Дом красный"),
                    w("Heime", "Дома", "adv", "Eg er heime nå", "Я сейчас дома"),
                    w("Skule", "Школа", "m", "Barna er på skulen", "Дети в школе"),
                    w("Butikk", "Магазин", "m", "Eg skal på butikken", "Я собираюсь в магазин"),
                    w("Her", "Здесь", "adv", "Bur du her?", "Ты живешь здесь?"),
                    w("Der", "Там", "adv", "Der er bilen min", "Там моя машина"),
                    w("By", "Город", "m", "Bergen er ein fin by", "Берген — красивый город"),
                    w("Rom", "Комната", "n", "Dette er mitt rom", "Это моя комната")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme6",
                nynorskTitle: "Mat og drikke",
                translations: ["Russian": "Еда и напитки", "English": "Food & Drink"],
                emoji: "cup.and.saucer.fill",
                difficulty: "A0",
                color: "orange",
                words: [
                    w("Mat", "Еда", "m", "Maten er god", "Еда вкусная"),
                    w("Vatn", "Вода", "n", "Kan eg få vatn?", "Можно мне воды?"),
                    w("Brød", "Хлеб", "n", "Eg kjøper brød", "Я покупаю хлеб"),
                    w("Mjølk", "Молоко", "f", "Likar du mjølk?", "Ты любишь молоко?"),
                    w("Kaffi", "Кофе", "m", "Eg vil ha svart kaffi", "Я хочу черный кофе"),
                    w("Te", "Чай", "m", "Vil du ha te?", "Ты хочешь чаю?"),
                    w("Ost", "Сыр", "m", "Brød med ost", "Хлеб с сыром"),
                    w("Frukt", "Фрукт", "m", "Eple er ei frukt", "Яблоко — это фрукт")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme7",
                nynorskTitle: "Kropp og helse",
                translations: ["Russian": "Тело и здоровье", "English": "Body & Health"],
                emoji: "heart.fill",
                difficulty: "A0",
                color: "pink",
                words: [
                    w("Kropp", "Тело", "m", "Kroppen treng mat", "Телу нужна еда"),
                    w("Hovud", "Голова", "n", "Eg har vondt i hovudet", "У меня болит голова"),
                    w("Hand", "Рука (кисть)", "f", "Vask hendene dine", "Помой свои руки"),
                    w("Fot", "Нога (стопа)", "m", "Han har store føter", "У него большие ноги"),
                    w("Auge", "Глаз", "n", "Ho har blå auge", "У нее голубые глаза"),
                    w("Mage", "Живот", "m", "Eg er mett i magen", "Я сыт"),
                    w("Sjuk", "Больной", "adj", "Eg er litt sjuk i dag", "Я сегодня немного болен"),
                    w("Frisk", "Здоровый", "adj", "Er du frisk?", "Ты здоров?")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme8",
                nynorskTitle: "Adjektiv og Fargar",
                translations: ["Russian": "Цвета и признаки", "English": "Adjectives & Colors"],
                emoji: "paintpalette.fill",
                difficulty: "A0",
                color: "purple",
                words: [
                    w("Stor", "Большой", "adj", "Bilen er stor", "Машина большая"),
                    w("Liten", "Маленький", "adj", "Huset er lite", "Дом маленький"),
                    w("God", "Хороший/Вкусный", "adj", "Du er ein god ven", "Ты хороший друг"),
                    w("Varm", "Теплый/Горячий", "adj", "Det er varmt i dag", "Сегодня тепло"),
                    w("Kald", "Холодный", "adj", "Vatnet er kaldt", "Вода холодная"),
                    w("Raud", "Красный", "adj", "Eplet er raudt", "Яблоко красное"),
                    w("Blå", "Синий/Голубой", "adj", "Himmelen er blå", "Небо голубое"),
                    w("Grøn", "Зеленый", "adj", "Graset er grønt", "Трава зеленая"),
                    w("Kvit", "Белый", "adj", "Snøen er kvit", "Снег белый"),
                    w("Svart", "Черный", "adj", "Eg har ein svart katt", "У меня есть черный кот")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme9",
                nynorskTitle: "Vêr og natur",
                translations: ["Russian": "Погода и природа", "English": "Weather & Nature"],
                emoji: "cloud.sun.fill",
                difficulty: "A0",
                color: "green",
                words: [
                    w("Vêr", "Погода", "n", "Korleis er vêret?", "Как погода?"),
                    w("Sol", "Солнце", "f", "Sola skin", "Солнце светит"),
                    w("Regn", "Дождь", "n", "Det er mykje regn i dag", "Сегодня много дождя"),
                    w("Snø", "Снег", "m", "Det er snø ute", "На улице снег"),
                    w("Vind", "Ветер", "m", "Det er mykje vind", "Очень ветрено"),
                    w("Natur", "Природа", "m", "Norsk natur er flott", "Норвежская природа прекрасна"),
                    w("Tre", "Дерево", "n", "Det er eit høgt tre", "Это высокое дерево")
                ]
            ),
            
            PresetTopic(
                id: "a0_theme10",
                nynorskTitle: "Enkle spørsmål",
                translations: ["Russian": "Простые вопросы", "English": "Simple Questions"],
                emoji: "questionmark.circle.fill",
                difficulty: "A0",
                color: "yellow",
                words: [
                    w("Kva", "Что", "pron", "Kva er det?", "Что это?"),
                    w("Kven", "Кто", "pron", "Kven er du?", "Кто ты?"),
                    w("Kvar", "Где", "adv", "Kvar er toalettet?", "Где туалет?"),
                    w("Korleis", "Как", "adv", "Korleis går det?", "Как дела?"),
                    w("Kvifor", "Почему", "adv", "Kvifor gret du?", "Почему ты плачешь?"),
                    w("Kva tid", "Когда", "adv", "Kva tid kjem bussen?", "Когда придет автобус?")
                ]
            ),
            
            // MARK: --- LEVEL A1 ---
            
            PresetTopic(
                id: "a1_theme1",
                nynorskTitle: "Familie og relasjonar",
                translations: ["Russian": "Семья и отношения", "English": "Family"],
                emoji: "figure.2.and.child.holdinghands",
                difficulty: "A1",
                color: "green",
                words: [
                    w("Familie", "Семья", "m", "Eg er glad i familien min", "Я люблю свою семью"),
                    w("Mor", "Мать", "f", "Mora mi er snill", "Моя мама добрая"),
                    w("Far", "Отец", "m", "Faren min jobbar mykje", "Мой папа много работает"),
                    w("Foreldre", "Родители", "m pl", "Foreldra mine bur i Oslo", "Мои родители живут в Осло"),
                    w("Bror", "Брат", "m", "Har du ein bror?", "У тебя есть брат?"),
                    w("Søster", "Сестра", "f", "Eg har ei lita søster", "У меня есть младшая сестра"),
                    w("Barn", "Ребенок", "n", "Dei har to barn", "У них двое детей"),
                    w("Son", "Сын", "m", "Sonen hennar er fem år", "Ее сыну пять лет"),
                    w("Dotter", "Дочь", "f", "Dottera vår går på skulen", "Наша дочь ходит в школу"),
                    w("Gift", "Женат/Замужем", "adj", "Er du gift?", "Ты женат/замужем?"),
                    w("Ven", "Друг", "m", "Han er min beste ven", "Он мой лучший друг")
                ]
            ),
            
            PresetTopic(
                id: "a1_theme2",
                nynorskTitle: "Kvardag og fritid",
                translations: ["Russian": "Будни и отдых", "English": "Daily Life"],
                emoji: "sun.max.fill",
                difficulty: "A1",
                color: "orange",
                words: [
                    w("Frukost", "Завтрак", "m", "Eg et frukost klokka sju", "Я ем завтрак в семь часов"),
                    w("Middag", "Обед/Ужин", "m", "Kva skal vi ha til middag?", "Что у нас будет на обед?"),
                    w("Lunsj", "Ланч", "m", "Eg har lunsj på jobben", "У меня ланч на работе"),
                    w("Våkne", "Просыпаться", "v", "Eg vaknar tidleg", "Я просыпаюсь рано"),
                    w("Kle på seg", "Одеваться", "v", "Eg kler på meg raskt", "Я быстро одеваюсь"),
                    w("Jobbe", "Работать", "v", "Eg jobbar kvar dag", "Я работаю каждый день"),
                    w("Slappe av", "Отдыхать", "v", "I kveld skal eg slappe av", "Сегодня вечером я буду отдыхать"),
                    w("Fritid", "Свободное время", "f", "Kva gjer du i fritida?", "Что ты делаешь в свободное время?"),
                    w("Lese", "Читать", "v", "Eg likar å lese bøker", "Мне нравится читать книги"),
                    w("Trening", "Тренировка", "f", "Eg går på trening i dag", "Я иду на тренировку сегодня"),
                    w("Helg", "Выходные", "f", "God helg!", "Хороших выходных!")
                ]
            ),
            
            PresetTopic(
                id: "a1_theme3",
                nynorskTitle: "Mat, handling og restaurant",
                translations: ["Russian": "Еда и покупки", "English": "Shopping & Food"],
                emoji: "cart.fill",
                difficulty: "A1",
                color: "red",
                words: [
                    w("Kjøpe", "Покупать", "v", "Eg må kjøpe mjølk", "Мне нужно купить молоко"),
                    w("Koste", "Стоить", "v", "Kva kostar det?", "Сколько это стоит?"),
                    w("Pose", "Пакет", "m", "Treng du pose?", "Тебе нужен пакет?"),
                    w("Kvittering", "Чек", "m", "Vil du ha kvittering?", "Ты хочешь чек?"),
                    w("Grønsak", "Овощ", "f", "Vi må ete meir grønsaker", "Нам нужно есть больше овощей"),
                    w("Kylling", "Курица", "m", "Likar du kylling?", "Тебе нравится курица?"),
                    w("Fisk", "Рыба", "m", "Norsk fisk er kjent", "Норвежская рыба известна"),
                    w("Restaurant", "Ресторан", "m", "Vi skal på restaurant i kveld", "Мы пойдем в ресторан сегодня вечером"),
                    w("Bestille", "Заказывать", "v", "Eg vil gjerne bestille", "Я бы хотел сделать заказ"),
                    w("Meny", "Меню", "m", "Kan eg få menyen?", "Можно мне меню?")
                ]
            ),
            
            PresetTopic(
                id: "a1_theme4",
                nynorskTitle: "Stad, transport og reise",
                translations: ["Russian": "Транспорт и Путешествия", "English": "Transport"],
                emoji: "car.fill",
                difficulty: "A1",
                color: "gray",
                words: [
                    w("Transport", "Транспорт", "m", "Offentleg transport er viktig", "Общественный транспорт важен"),
                    w("Buss", "Автобус", "m", "Bussen går om ti minutt", "Автобус отходит через десять минут"),
                    w("Tog", "Поезд", "n", "Toget er forsinka", "Поезд опаздывает"),
                    w("Bil", "Машина", "m", "Eg køyrer bil til jobb", "Я еду на машине на работу"),
                    w("Billett", "Билет", "m", "Har du billett?", "У тебя есть билет?"),
                    w("Stasjon", "Станция", "m", "Vi møtest på stasjonen", "Мы встретимся на станции"),
                    w("Flyplass", "Аэропорт", "m", "Flyplassen er stor", "Аэропорт большой"),
                    w("Reise", "Путешествовать", "v", "Eg likar å reise", "Мне нравится путешествовать"),
                    w("Køyre", "Водить/Ехать", "v", "Kan du køyre meg?", "Можешь меня подвезти?"),
                    w("Sykkel", "Велосипед", "m", "Eg syklar til skulen", "Я еду на велосипеде в школу")
                ]
            ),
            
            PresetTopic(
                id: "a1_theme5",
                nynorskTitle: "Arbeid",
                translations: ["Russian": "Работа", "English": "Work"],
                emoji: "briefcase.fill",
                difficulty: "A1",
                color: "blue",
                words: [
                    w("Arbeid", "Работа (труд)", "n", "Det er eit tungt arbeid", "Это тяжелая работа"),
                    w("Jobb", "Работа (место)", "m", "Eg har fått ny jobb", "Я получил новую работу"),
                    w("Sjef", "Начальник", "m", "Sjefen min er grei", "Мой начальник нормальный"),
                    w("Kollega", "Коллега", "m", "Eg har hyggjelege kollegaer", "У меня приятные коллеги"),
                    w("Kontor", "Офис", "n", "Eg sit på kontoret", "Я сижу в офисе"),
                    w("Møte", "Встреча/Собрание", "n", "Vi har møte klokka to", "У нас собрание в два часа"),
                    w("Løn", "Зарплата", "f", "Når får vi løn?", "Когда мы получим зарплату?"),
                    w("Pause", "Перерыв", "m", "Nå er det pause", "Сейчас перерыв")
                ]
            ),
            
            // MARK: --- LEVEL A2 ---
            
            PresetTopic(
                id: "a2_theme1",
                nynorskTitle: "Helse og kvardag",
                translations: ["Russian": "Здоровье", "English": "Health"],
                emoji: "cross.case.fill",
                difficulty: "A2",
                color: "pink",
                words: [
                    w("Lege", "Врач", "m", "Eg må bestille time hos legen", "Мне нужно записаться к врачу"),
                    w("Sjukehus", "Больница", "n", "Han ligg på sjukehuset", "Он лежит в больнице"),
                    w("Medisin", "Лекарство", "m", "Du må ta medisinen din", "Ты должен принять свое лекарство"),
                    w("Feber", "Температура (жар)", "m", "Barnet har høg feber", "У ребенка высокая температура"),
                    w("Vondt", "Больно/Боль", "adv/n", "Eg har vondt i ryggen", "У меня болит спина"),
                    w("Forkjøla", "Простуженный", "adj", "Eg er blitt forkjøla", "Я простудился"),
                    w("Tannlege", "Зубной врач", "m", "Tannlegen er dyr i Noreg", "Стоматолог в Норвегии дорогой"),
                    w("Resept", "Рецепт", "m", "Eg fekk resept på antibiotika", "Я получил рецепт на антибиотики"),
                    w("Legevakt", "Травмпункт", "f", "Vi måtte dra på legevakta", "Нам пришлось ехать в травмпункт"),
                    w("Betre", "Лучше", "adj", "Kjenner du deg betre?", "Ты чувствуешь себя лучше?"),
                    w("Verke", "Болеть (ныть)", "v", "Det verkjer i foten", "Нога ноет (болит)")
                ]
            ),
            
            PresetTopic(
                id: "a2_theme2",
                nynorskTitle: "Bustad og daglegliv",
                translations: ["Russian": "Жилье и быт", "English": "Housing"],
                emoji: "house.fill",
                difficulty: "A2",
                color: "brown",
                words: [
                    w("Leilegheit", "Квартира", "f", "Vi leiger ei fin leilegheit", "Мы снимаем хорошую квартиру"),
                    w("Enebolig", "Частный дом", "m", "Draumen er ein enebolig", "Мечта — это частный дом"),
                    w("Husleige", "Арендная плата", "f", "Husleiga er høg her", "Арендная плата здесь высокая"),
                    w("Nabolag", "Район", "n", "Nabolaget er roleg", "Район спокойный"),
                    w("Møblar", "Мебель", "m pl", "Vi treng nye møblar", "Нам нужна новая мебель"),
                    w("Stove", "Гостиная", "f", "Vi sit i stova og ser på TV", "Мы сидим в гостиной и смотрим телевизор"),
                    w("Kjøkken", "Кухня", "n", "Likar du å lage mat på kjøkkenet?", "Тебе нравится готовить на кухне?"),
                    w("Bad", "Ванная комната", "n", "Badet er nyoppussa", "Ванная комната недавно отремонтирована"),
                    w("Hage", "Сад", "m", "Eg arbeider i hagen", "Я работаю в саду"),
                    w("Flytte", "Переезжать", "v", "Vi skal flytte neste veke", "Мы переезжаем на следующей неделе"),
                    w("Nøkkel", "Ключ", "m", "Kvar er nøkkelen min?", "Где мой ключ?")
                ]
            ),
            
            PresetTopic(
                id: "a2_theme3",
                nynorskTitle: "Handling og tenester",
                translations: ["Russian": "Покупки и услуги", "English": "Services"],
                emoji: "bag.fill",
                difficulty: "A2",
                color: "teal",
                words: [
                    w("Klede", "Одежда", "n pl", "Eg treng varme klede", "Мне нужна теплая одежда"),
                    w("Sal", "Распродажа", "n", "Det er sal på vintersko", "Сейчас распродажа зимней обуви"),
                    w("Storleik", "Размер", "m", "Har de denne i storleik 40?", "У вас есть это в 40-м размере?"),
                    w("Dyr", "Дорогой", "adj", "Bilen var veldig dyr", "Машина была очень дорогой"),
                    w("Billeg", "Дешевый", "adj", "Mat er ikkje billeg her", "Еда здесь не дешевая"),
                    w("Opningstid", "Время работы", "f", "Kva er opningstida til biblioteket?", "Какое время работы у библиотеки?"),
                    w("Bibliotek", "Библиотека", "n", "Eg låner bøker på biblioteket", "Я беру книги в библиотеке"),
                    w("Frisør", "Парикмахер", "m", "Eg har time hos frisøren", "У меня запись к парикмахеру"),
                    w("Bankkort", "Банковская карта", "n", "Eg betaler med bankkort", "Я плачу банковской картой"),
                    w("Kontantar", "Наличные", "m pl", "Tar de kontantar?", "Вы принимаете наличные?"),
                    w("Byte", "Менять", "v", "Kan eg byte genseren?", "Могу я поменять свитер?")
                ]
            ),
            
            PresetTopic(
                id: "a2_theme4",
                nynorskTitle: "Arbeid og rettar",
                translations: ["Russian": "Работа и права", "English": "Work Rights"],
                emoji: "doc.text.fill",
                difficulty: "A2",
                color: "indigo",
                words: [
                    w("Arbeidskontrakt", "Трудовой договор", "m", "Har du skrive under på arbeidskontrakten?", "Ты подписал трудовой договор?"),
                    w("Skatt", "Налог", "m", "Vi betaler skatt av løna", "Мы платим налог с зарплаты"),
                    w("Ferie", "Отпуск", "m", "Når skal du ha ferie?", "Когда у тебя будет отпуск?"),
                    w("Eigenmelding", "Заявление о болезни", "f", "Du kan bruke eigenmelding i tre dagar", "Ты можешь использовать 'эгенмелдинг' три дня"),
                    w("Søknad", "Заявка", "m", "Eg har sendt ein søknad på jobben", "Я отправил заявку на работу"),
                    w("Erfaring", "Опыт", "f", "Har du erfaring frå butikk?", "У тебя есть опыт работы в магазине?"),
                    w("Attest", "Характеристика", "m", "Sjefen gav meg ein god attest", "Начальник дал мне хорошую характеристику"),
                    w("Vikar", "Заместитель", "m", "Eg jobbar som vikar", "Я работаю временным заместителем")
                ]
            ),
            
            PresetTopic(
                id: "a2_theme5",
                nynorskTitle: "Kjensler og meiningar",
                translations: ["Russian": "Чувства и мнения", "English": "Feelings"],
                emoji: "face.smiling.fill",
                difficulty: "A2",
                color: "yellow",
                words: [
                    w("Glad", "Рад/Счастлив", "adj", "Eg er så glad i dag", "Я так рад сегодня"),
                    w("Trist", "Грустный", "adj", "Det er ei trist historie", "Это грустная история"),
                    w("Sint", "Злой", "adj", "Kvifor er du sint?", "Почему ты злишься?"),
                    w("Redd", "Испуганный", "adj", "Eg er redd for hundar", "Я боюсь собак"),
                    w("Synast", "Считать", "v", "Eg synest det er kaldt", "Я считаю, что холодно"),
                    w("Tru", "Думать/Верить", "v", "Eg trur det blir regn", "Я думаю, что будет дождь"),
                    w("Meine", "Иметь мнение", "v", "Kva meiner du om saka?", "Что ты думаешь об этом деле?"),
                    w("Håpe", "Надеяться", "v", "Eg håpar du kjem", "Я надеюсь, ты придешь"),
                    w("Overraska", "Удивленный", "adj", "Eg vart veldig overraska", "Я был очень удивлен"),
                    w("Sjalu", "Ревнивый", "adj", "Han er litt sjalu", "Он немного ревнив")
                ]
            ),
            
            // MARK: --- LEVEL B1 ---
            
            PresetTopic(
                id: "b1_theme1",
                nynorskTitle: "Erfaring og livshistorie",
                translations: ["Russian": "Опыт и история", "English": "Life History"],
                emoji: "book.fill",
                difficulty: "B1",
                color: "brown",
                words: [
                    w("Oppvekst", "Детство", "m", "Eg hadde ein fin oppvekst på landet", "У меня было хорошее детство в деревне"),
                    w("Barndom", "Детство", "m", "I min barndom leika vi ute", "В моем детстве мы играли на улице"),
                    w("Minne", "Воспоминание", "n", "Det er eit godt minne", "Это хорошее воспоминание"),
                    w("Hugse", "Помнить", "v", "Hugsar du kva eg sa?", "Ты помнишь, что я сказал?"),
                    w("Gløyme", "Забыть", "v", "Eg gløymde avtalen", "Я забыл о встрече"),
                    w("Utdanning", "Образование", "f", "Utdanning er viktig for framtida", "Образование важно для будущего"),
                    w("Draume", "Мечтать", "v", "Eg draumar om å reise jorda rundt", "Я мечтаю путешествовать вокруг света"),
                    w("Angre", "Жалеть", "v", "Eg angrar ikkje på valet mitt", "Я не жалею о своем выборе"),
                    w("Endre seg", "Меняться", "v", "Samfunnet endrar seg raskt", "Общество быстро меняется"),
                    w("Oppleve", "Переживать", "v", "Vi opplevde mykje spennande", "Мы пережили много захватывающего")
                ]
            ),
            
            PresetTopic(
                id: "b1_theme2",
                nynorskTitle: "Samfunn og kvardag",
                translations: ["Russian": "Общество", "English": "Society"],
                emoji: "globe.europe.africa.fill",
                difficulty: "B1",
                color: "blue",
                words: [
                    w("Samfunn", "Общество", "n", "Det norske samfunnet bygger på tillit", "Норвежское общество строится на доверии"),
                    w("Demokrati", "Демократия", "n", "Ytringsfridom er viktig i eit demokrati", "Свобода слова важна в демократии"),
                    w("Val", "Выборы", "n", "Det er val annakvart år", "Выборы проходят каждые два года"),
                    w("Innbyggjar", "Житель", "m", "Kommunen har mange innbyggjarar", "В коммуне много жителей"),
                    w("Miljø", "Окружающая среда", "n", "Vi må ta vare på miljøet", "Мы должны заботиться об окружающей среде"),
                    w("Berekraftig", "Устойчивый", "adj", "Vi treng berekraftig utvikling", "Нам нужно устойчивое развитие"),
                    w("Kultur", "Культура", "m", "Kultur og tradisjonar høyrer saman", "Культура и традиции идут вместе"),
                    w("Likestilling", "Равноправие", "f", "Noreg er kjent for likestilling", "Норвегия известна равноправием"),
                    w("Frivillig", "Добровольный", "adj", "Mange gjer frivillig arbeid", "Многие занимаются волонтерской работой"),
                    w("Dugnad", "Субботник", "m", "Vi skal på dugnad i burettslaget", "Мы идем на субботник в жилищном кооперативе")
                ]
            ),
            
            PresetTopic(
                id: "b1_theme3",
                nynorskTitle: "Argumentasjon",
                translations: ["Russian": "Аргументация", "English": "Argumentation"],
                emoji: "bubble.left.and.bubble.right.fill",
                difficulty: "B1",
                color: "orange",
                words: [
                    w("Fordel", "Преимущество", "m", "Ein fordel med byen er kollektivtrafikken", "Преимущество города — общественный транспорт"),
                    w("Ulempe", "Недостаток", "f", "Ei ulempe er at det er dyrt", "Недостаток в том, что это дорого"),
                    w("Einig", "Согласен", "adj", "Eg er heilt einig med deg", "Я полностью с тобой согласен"),
                    w("Ueinig", "Не согласен", "adj", "Vi er ueinige om politikken", "Мы не согласны насчет политики"),
                    w("Derimot", "Напротив/Зато", "adv", "Han likar fisk, eg derimot likar kjøt", "Он любит рыбу, я же, напротив, люблю мясо"),
                    w("Difor", "Поэтому", "adv", "Det regnar, difor er eg inne", "Идет дождь, поэтому я внутри"),
                    w("Likevel", "Тем не менее", "adv", "Det var kaldt, men vi gjekk likevel", "Было холодно, но мы все же пошли"),
                    w("På den eina sida", "С одной стороны", "frase", "På den eina sida er det billig", "С одной стороны, это дешево"),
                    w("På den andre sida", "С другой стороны", "frase", "På den andre sida er kvaliteten dårleg", "С другой стороны, качество плохое"),
                    w("Viktig", "Важный", "adj", "Det er viktig å seie meininga si", "Важно говорить свое мнение")
                ]
            ),
            
            // MARK: --- LEVEL B2 ---
            
            PresetTopic(
                id: "b2_theme1",
                nynorskTitle: "Abstrakte omgrep",
                translations: ["Russian": "Абстрактные понятия", "English": "Abstract Concepts"],
                emoji: "brain.head.profile",
                difficulty: "B2",
                color: "purple",
                words: [
                    w("Omgrep", "Понятие", "n", "Det er eit vanskeleg omgrep å forklare", "Это сложное понятие для объяснения"),
                    w("Kunnskap", "Знание", "m", "Kunnskap er makt", "Знание — сила"),
                    w("Moglegheit", "Возможность", "f", "Dette gir oss nye moglegheiter", "Это дает нам новые возможности"),
                    w("Samanheng", "Контекст", "m", "Vi må sjå dette i ein større samanheng", "Мы должны рассматривать это в большем контексте"),
                    w("Ansvar", "Ответственность", "n", "Du har ansvar for eiga læring", "Ты несешь ответственность за собственное обучение"),
                    w("Fridom", "Свобода", "m", "Fridom under ansvar", "Свобода под ответственностью"),
                    w("Verdi", "Ценность", "m", "Kva verdiar er viktige for deg?", "Какие ценности важны для тебя?"),
                    w("Føresetnad", "Предпосылка", "m", "Ein føresetnad for suksess er hardt arbeid", "Предпосылка успеха — тяжелая работа"),
                    w("Utfordring", "Вызов", "f", "Klimaendringar er ei stor utfordring", "Изменение климата — большой вызов"),
                    w("Eigenskap", "Свойство", "m", "Tolmod er ein god eigenskap", "Терпение — хорошее качество")
                ]
            ),
            
            PresetTopic(
                id: "b2_theme2",
                nynorskTitle: "Diskusjon og nyansar",
                translations: ["Russian": "Дискуссия и нюансы", "English": "Discussion"],
                emoji: "mic.fill",
                difficulty: "B2",
                color: "indigo",
                words: [
                    w("Hevde", "Утверждать", "v", "Han hevdar at han har rett", "Он утверждает, что он прав"),
                    w("Påstå", "Заявлять", "v", "Dei påstår at det ikkje er farleg", "Они заявляют, что это не опасно"),
                    w("Tvile", "Сомневаться", "v", "Eg tvilar på at det er sant", "Я сомневаюсь, что это правда"),
                    w("Overbevise", "Убеждать", "v", "Du må overbevise meg med fakta", "Ты должен убедить меня фактами"),
                    w("Vurdere", "Оценивать", "v", "Vi må vurdere ulike løysingar", "Мы должны рассмотреть разные решения"),
                    w("Avhenge av", "Зависеть от", "v", "Det avheng av vêret", "Это зависит от погоды"),
                    w("Tilsvarande", "Соответствующий", "adj", "Vi søkjer etter ein tilsvarande stilling", "Мы ищем соответствующую должность"),
                    w("Vesentlig", "Существенный", "adj", "Det er ein vesentlig forskjell", "Это существенная разница"),
                    w("Nyansert", "Нюансированный", "adj", "Vi treng eit nyansert bilete av saka", "Нам нужна нюансированная картина дела"),
                    w("Antakeleg", "Вероятно", "adv", "Det er antakeleg den beste løysinga", "Это, вероятно, лучшее решение")
                ]
            ),
            
            PresetTopic(
                id: "b2_theme3",
                nynorskTitle: "Media og debatt",
                translations: ["Russian": "Медиа и дебаты", "English": "Media & Debate"],
                emoji: "newspaper.fill",
                difficulty: "B2",
                color: "red",
                words: [
                    w("Ytringsfridom", "Свобода слова", "m", "Ytringsfridom er ein menneskerett", "Свобода слова — это право человека"),
                    w("Kjeldekritikk", "Критика источников", "m", "Kjeldekritikk er viktig på internett", "Критика источников важна в интернете"),
                    w("Påverknad", "Влияние", "m", "Sosiale medium har stor påverknad", "Социальные сети имеют большое влияние"),
                    w("Debatt", "Дебаты", "m", "Det var ein hissig debatt på TV", "Были жаркие дебаты по ТВ"),
                    w("Fagforeining", "Профсоюз", "f", "Mange er medlem i ei fagforeining", "Многие являются членами профсоюза"),
                    w("Arbeidsløyse", "Безработица", "f", "Arbeidsløysa går ned", "Безработица снижается"),
                    w("Integrering", "Интеграция", "f", "God integrering er viktig for samfunnet", "Хорошая интеграция важна для общества"),
                    w("Velferd", "Благосостояние", "f", "Velferdsstaten sikrar oss hjelp", "Государство всеобщего благосостояния гарантирует нам помощь"),
                    w("Rettferd", "Справедливость", "f", "Vi må kjempe for rettferd", "Мы должны бороться за справедливость"),
                    w("Befolkning", "Население", "f", "Befolkninga i verda aukar", "Население в мире растет")
                ]
            ),
            
            // MARK: --- GRAMMAR ---
            
            PresetTopic(
                id: "g1_nouns",
                nynorskTitle: "Substantiv",
                translations: ["Russian": "Существительные", "English": "Nouns"],
                emoji: "cube.fill",
                difficulty: "Grammar",
                color: "blue",
                words: [
                    w("Ei jente", "Девочка (ж.р.)", "f", "Ei jente - jenta - jenter - jentene", "Девочка - (эта) девочка - девочки - (эти) девочки"),
                    w("Ei bok", "Книга (ж.р.)", "f", "Ei bok - boka - bøker - bøkene", "Книга - (эта) книга - книги - (эти) книги"),
                    w("Ein bil", "Машина (м.р.)", "m", "Ein bil - bilen - bilar - bilane", "Машина - (эта) машина - машины - (эти) машины"),
                    w("Ein gut", "Мальчик (м.р.)", "m", "Ein gut - guten - gutar - gutane", "Мальчик - (этот) мальчик - мальчики - (эти) мальчики"),
                    w("Eit hus", "Дом (ср.р.)", "n", "Eit hus - huset - hus - husa", "Дом - (этот) дом - дома - (эти) дома"),
                    w("Eit eple", "Яблоко (ср.р.)", "n", "Eit eple - eplet - eple - epla", "Яблоко - (это) яблоко - яблоки - (эти) яблоки"),
                    w("Bøying", "Склонение", "f", "Vi må øve på bøying", "Мы должны тренировать склонение"),
                    w("Ending", "Окончание", "f", "Hokjønn har endinga -a", "У женского рода окончание -а")
                ]
            ),
            
            PresetTopic(
                id: "g2_verbs",
                nynorskTitle: "Verb",
                translations: ["Russian": "Глаголы", "English": "Verbs"],
                emoji: "arrow.triangle.2.circlepath",
                difficulty: "Grammar",
                color: "orange",
                words: [
                    w("Å snakke", "Говорить (a-verb)", "v", "Eg snakkar - eg snakka - eg har snakka", "Я говорю - я говорил - я говорил (perf.)"),
                    w("Å kaste", "Бросать (a-verb)", "v", "Han kastar - han kasta - han har kasta", "Он бросает - он бросил - он бросил (perf.)"),
                    w("Å kjøpe", "Покупать (e-verb)", "v", "Vi kjøper - vi kjøpte - vi har kjøpt", "Мы покупаем - мы купили - мы купили (perf.)"),
                    w("Å lese", "Читать (e-verb)", "v", "Du les - du las - du har lese", "Ты читаешь - ты читал - ты читал (perf.)"),
                    w("Å skrive", "Писать (сильный verb)", "v", "Eg skriv - eg skreiv - eg har skrive", "Я пишу - я писал - я написал"),
                    w("Å vere", "Быть (uregelrett)", "v", "Eg er - eg var - eg har vore", "Я есть - я был - я был (perf.)"),
                    w("Å bli", "Становиться", "v", "Eg blir - eg blei - eg har blitt", "Я становлюсь - я стал - я стал (perf.)")
                ]
            ),
            
            PresetTopic(
                id: "g3_small",
                nynorskTitle: "Småord",
                translations: ["Russian": "Частицы и местоимения", "English": "Particles"],
                emoji: "puzzlepiece.fill",
                difficulty: "Grammar",
                color: "green",
                words: [
                    w("Eg", "Я", "pron", "Eg bur i Noreg", "Я живу в Норвегии"),
                    w("Ikkje", "Не", "adv", "Eg forstår ikkje", "Я не понимаю"),
                    w("Noko", "Что-то", "pron", "Har du noko å drikke?", "У тебя есть что-то попить?"),
                    w("Nokon", "Кто-то", "pron", "Ser du nokon her?", "Ты видишь кого-то здесь?"),
                    w("Kven", "Кто", "pron", "Kven er det?", "Кто это?"),
                    w("Kva", "Что", "pron", "Kva sa du?", "Что ты сказал?"),
                    w("Kvar", "Где/Куда", "adv", "Kvar skal du?", "Куда ты идешь?"),
                    w("Kvifor", "Почему", "adv", "Kvifor spør du?", "Почему ты спрашиваешь?"),
                    w("Korleis", "Как", "adv", "Korleis har du det?", "Как у тебя дела?"),
                    w("Dykkar", "Ваш", "pron", "Er dette huset dykkar?", "Это ваш дом?"),
                    w("Vår", "Наш", "pron", "Bilen vår er grøn", "Наша машина зеленая")
                ]
            ),
            
            PresetTopic(
                id: "g4_det",
                nynorskTitle: "Determinativ",
                translations: ["Russian": "Детерминативы", "English": "Determiners"],
                emoji: "hand.point.up.left.fill",
                difficulty: "Grammar",
                color: "yellow",
                words: [
                    w("Denne", "Этот", "det", "Denne boka er min", "Эта книга моя"),
                    w("Dette", "Это", "det", "Dette huset er gamalt", "Этот дом старый"),
                    w("Desse", "Эти", "det", "Desse bilane er nye", "Эти машины новые"),
                    w("Den", "Тот/Та", "det", "Den stolen er oppteken", "Тот стул занят"),
                    w("Det", "То", "det", "Det treet er høgt", "То дерево высокое"),
                    w("Dei", "Те / Они", "det/pron", "Dei bøkene er dyre", "Те книги дорогие")
                ]
            )
        ]
    }
}
