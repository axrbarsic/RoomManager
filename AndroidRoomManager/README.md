# Room Manager Android

Android companion app for iOS Room Manager with real-time Firebase sync.

## Status: PRODUCTION READY ✅

- **Auto-authentication**: axrbarsic@gmail.com
- **Real-time sync**: Firebase Firestore  
- **Visual parity**: Identical to iOS app
- **Localization**: 5 languages (auto-detect)
- **Responsive**: All screen sizes

## Quick Commands:
```bash
./gradlew assembleDebug     # Build APK
./gradlew installDebug      # Install on device
```

## Technical Details:
See `AI_TECHNICAL_SUMMARY.md` for complete technical documentation.

## 🚀 Быстрый старт

1. **Откройте проект в Android Studio**
2. **Дождитесь синхронизации Gradle**
3. **Запустите на устройстве или эмуляторе**

> 📋 Подробные инструкции в [QUICK_START.md](QUICK_START.md)

## ✨ Возможности

### 🔄 Real-time синхронизация
- Мгновенная синхронизация с iOS приложением
- Автоматическое переподключение при потере связи
- Анонимная аутентификация Firebase

### 🎨 Современный UI
- Material Design 3 с темной темой
- Адаптивная сетка комнат
- Цветовая кодировка статусов
- Плавные анимации и переходы

### 📊 Аналитика
- Статистика по статусам комнат в реальном времени
- Автоматическое определение этажей
- Фильтрация и настройки отображения

## 🔧 Технологии

- **Kotlin** + **Jetpack Compose**
- **Firebase Firestore** для real-time синхронизации
- **Firebase Auth** с Google Sign-In
- **Material Design 3**
- **MVVM архитектура** с StateFlow
- **Coroutines** для асинхронных операций

## 📱 Авторизация

### Google Sign-In
1. Нажмите "Войти с Google" на экране подключения
2. Выберите Google аккаунт
3. Данные автоматически синхронизируются с iOS приложением

### Анонимная авторизация
1. Нажмите "Подключиться" для быстрого доступа
2. Данные будут доступны только на этом устройстве

## 🔄 Синхронизация с iOS

Приложение автоматически синхронизируется с iOS приложением RoomManager:
- Изменения статусов комнат отображаются в реальном времени
- Пометки и индикаторы синхронизируются
- Статистика обновляется автоматически

### 🎯 Полная синхронизация состояний

**Все состояния ячеек из iOS полностью синхронизируются:**

- ✅ **Цвета комнат** - желтый, красный, зеленый, фиолетовый, синий, белый
- ✅ **Метки (isMarked)** - зеленый кружок в правом верхнем углу
- ✅ **Deep Clean (isDeepCleaned)** - синий кружок в левом верхнем углу  
- ✅ **Сделано до 9:30 (isCompletedBefore930)** - оранжевый кружок в левом нижнем углу
- ✅ **Время доступности** - отображается на фиолетовых комнатах
- ✅ **Добавление/удаление комнат** - мгновенно синхронизируется
- ✅ **Временные метки** - сохраняются все timestamps изменений

### 🔄 Real-time обновления

- **Мгновенная синхронизация** - изменения отображаются за 1-2 секунды
- **Автоматическое переподключение** при потере связи
- **Firebase Firestore** с real-time listeners
- **Cross-platform совместимость** iOS ↔ Android

📋 **Подробное тестирование:** [TESTING_SYNCHRONIZATION.md](TESTING_SYNCHRONIZATION.md)  
🔍 **Обзор синхронизации:** [SYNCHRONIZATION_OVERVIEW.md](SYNCHRONIZATION_OVERVIEW.md)

## 🏗️ Архитектура

```
AndroidRoomManager/
├── app/
│   ├── src/main/java/com/roommanager/android/
│   │   ├── ui/                    # UI компоненты
│   │   │   ├── MainActivity.kt    # Главный экран (476 строк)
│   │   │   ├── RoomViewModel.kt   # ViewModel (177 строк)
│   │   │   ├── components/
│   │   │   │   └── RoomCell.kt    # Компонент комнаты (247 строк)
│   │   │   └── theme/             # Темы и стили
│   │   ├── model/                 # Модели данных
│   │   │   ├── Room.kt           # Модель комнаты (42 строки)
│   │   │   └── FirebaseRoom.kt   # Firebase модель (85 строк)
│   │   └── firebase/             # Firebase интеграция
│   │       └── FirebaseManager.kt # Менеджер Firebase (224 строки)
│   └── google-services.json      # Конфигурация Firebase
└── README.md
```

**Всего: 1329 строк кода**

## 🎯 Статусы комнат

| Цвет | Статус | Описание |
|------|--------|----------|
| 🟡 | Желтый | Не убрана |
| 🔴 | Красный | Грязная/check out |
| 🟢 | Зеленый | Убрана |
| 🟣 | Фиолетовый | Доступна с времени |
| 🔵 | Синий | Out of order |
| ⚪ | Белый | Скрыта |

## 🔧 Технические детали

### Требования
- Android 7.0+ (API 24)
- Интернет соединение
- Google Play Services

### Firebase структура
```
/users/{userId}/rooms/{roomId}
├── id: String
├── number: String
├── color: String (yellow|red|green|purple|blue|white)
├── availableTime: String?
├── isMarked: Boolean
├── isDeepCleaned: Boolean
├── isCompletedBefore930: Boolean
└── lastModified: Timestamp
```

## 🔗 Синхронизация с iOS

Приложение автоматически синхронизируется с iOS версией:
- Изменения в iOS мгновенно отображаются в Android
- Общая база данных Firebase Firestore
- Одинаковая структура данных

## 🛠️ Разработка

### Сборка проекта
```bash
./gradlew assembleDebug
```

### Установка на устройство
```bash
./gradlew installDebug
```

### Очистка проекта
```bash
./gradlew clean
```

## 📱 Скриншоты функций

- **Главный экран**: Сетка комнат с цветовой кодировкой
- **Статистика**: Количество комнат по статусам
- **Фильтры**: По этажам и типам комнат
- **Настройки**: Скрытие белых комнат, показ только помеченных

## 🐛 Устранение неполадок

### Пустой экран
- Убедитесь, что iOS приложение создало данные в Firebase
- Проверьте интернет соединение

### Ошибка аутентификации
- Файл `google-services.json` должен быть в папке `app/`
- Проект ID: `rm2axrbarsic`

### Проблемы сборки
- Используйте Android Studio вместо командной строки
- Убедитесь в наличии Android SDK

## 📄 Лицензия

Проект создан для демонстрации возможностей cross-platform синхронизации.

---

**🎉 Готово к использованию! Откройте в Android Studio и запустите.**

---

**Версия:** 1.0.0  
**Последнее обновление:** Декабрь 2024 