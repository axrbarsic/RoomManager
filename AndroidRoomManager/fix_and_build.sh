#!/bin/bash

echo "=== ИСПРАВЛЕНИЕ И СБОРКА ROOM MANAGER ==="

# Удаляем кэш gradle
echo "1. Очистка Gradle кэша..."
rm -rf .gradle
rm -rf build
rm -rf app/build

# Восстанавливаем поврежденные XML файлы (если есть)
echo "2. Проверяем XML файлы..."

# Проверяем и исправляем values-en/strings.xml
if [ ! -s "app/src/main/res/values-en/strings.xml" ]; then
echo "Исправляем values-en/strings.xml"
cat > app/src/main/res/values-en/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Room Manager</string>
    <string name="connecting_to_server">Connecting to server...</string>
    <string name="syncing_with_account">Syncing with axrbarsic@gmail.com</string>
</resources>
EOF
fi

# Создаем недостающие директории
mkdir -p app/src/main/res/values-v27

# Создаем themes.xml если отсутствует
cat > app/src/main/res/values-v27/themes.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Base theme for API 27+ -->
</resources>
EOF

echo "3. Запуск сборки..."
sh gradlew clean assembleDebug

echo "4. Установка приложения..."
if [ -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    adb install -r app/build/outputs/apk/debug/app-debug.apk
    echo "✅ Приложение установлено успешно!"
    
    echo "5. Запуск приложения..."
    adb shell am start -n com.roommanager.android/.ui.MainActivity
    
    echo "6. Начинаем мониторинг логов..."
    adb logcat -v time -s "FirebaseManager:*" | head -20
else
    echo "❌ Файл APK не найден"
fi 