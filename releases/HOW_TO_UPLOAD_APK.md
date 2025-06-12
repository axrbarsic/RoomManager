# 📤 Как загрузить APK на GitHub через Releases

APK файлы слишком большие для обычного git репозитория (лимит GitHub ~100MB). Используйте **GitHub Releases** для публикации готовых APK файлов.

## 🚀 Пошаговая инструкция:

### 1. Подготовка APK файла:
```bash
# Соберите APK
cd AndroidRoomManager
./gradlew clean assembleDebug

# APK будет создан в:
# app/build/outputs/apk/debug/app-debug.apk (размер ~22MB)
```

### 2. Создание Release на GitHub:

1. **Перейдите в репозиторий**: https://github.com/axrbarsic/RoomManager
2. **Нажмите "Releases"** (справа от Code)
3. **"Create a new release"**
4. **Заполните поля**:
   - **Tag version**: `v1.0.0-android`
   - **Release title**: `RoomManager Android v1.0.0`
   - **Description**:
   ```markdown
   # RoomManager Android v1.0.0
   
   ## 📱 Готовое Android приложение для скачивания
   
   ### ✨ Особенности:
   - 🏠 Управление комнатами
   - 🔥 Firebase синхронизация с iOS
   - 🌍 Мультиязычность (EN, ES, UK, HT)
   - 📊 Статистика и аналитика
   
   ### 📋 Системные требования:
   - Android 7.0+ (API 24+)
   - 2GB RAM
   - 50MB свободного места
   
   ### 📲 Установка:
   1. Скачайте APK файл
   2. Разрешите установку из неизвестных источников
   3. Установите приложение
   ```

5. **Перетащите APK файл** в секцию "Attach binaries"
   - `app-debug.apk` → переименуйте в `RoomManager-Android-v1.0.0.apk`

6. **Нажмите "Publish release"**

### 3. Альтернативный способ (через терминал):

Если у вас установлен GitHub CLI:

```bash
# Создание release
gh release create v1.0.0-android \
  --title "RoomManager Android v1.0.0" \
  --notes "Первый релиз Android приложения RoomManager"

# Загрузка APK
gh release upload v1.0.0-android \
  AndroidRoomManager/app/build/outputs/apk/debug/app-debug.apk \
  --clobber
```

## 📋 Преимущества GitHub Releases:

- ✅ **Нет лимитов** размера файлов (до 2GB)
- ✅ **Быстрое скачивание** через CDN
- ✅ **Версионирование** релизов
- ✅ **Статистика** скачиваний
- ✅ **Автоматические** уведомления подписчикам

## 🔗 Ссылки:

- **Создать Release**: https://github.com/axrbarsic/RoomManager/releases/new
- **Все Releases**: https://github.com/axrbarsic/RoomManager/releases
- **GitHub Docs**: https://docs.github.com/en/repositories/releasing-projects-on-github

---
*Создано: 12 июня 2025* 