#!/bin/bash

# Скрипт для настройки URL схемы Google Sign-In

echo "🔧 Настройка URL схемы для Google Sign-In..."

# Получаем REVERSED_CLIENT_ID из GoogleService-Info.plist
PLIST_PATH="./GoogleService-Info.plist"

if [ ! -f "$PLIST_PATH" ]; then
    echo "❌ Файл GoogleService-Info.plist не найден"
    exit 1
fi

# Извлекаем REVERSED_CLIENT_ID
REVERSED_CLIENT_ID=$(plutil -extract REVERSED_CLIENT_ID raw "$PLIST_PATH" 2>/dev/null)

if [ -z "$REVERSED_CLIENT_ID" ]; then
    echo "❌ Не удалось получить REVERSED_CLIENT_ID из GoogleService-Info.plist"
    exit 1
fi

echo "✅ Получен REVERSED_CLIENT_ID: $REVERSED_CLIENT_ID"

# Находим файл проекта
PROJECT_FILE="../RoomManager.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Файл проекта не найден: $PROJECT_FILE"
    exit 1
fi

echo "📝 Инструкции по настройке URL схемы в Xcode:"
echo ""
echo "1. Откройте RoomManager.xcodeproj в Xcode"
echo "2. Выберите проект RoomManager в навигаторе проектов"
echo "3. Выберите таргет RoomManager"
echo "4. Перейдите на вкладку 'Info'"
echo "5. Разверните секцию 'URL Types'"
echo "6. Нажмите '+' для добавления новой URL схемы"
echo "7. В поле 'URL Schemes' введите: $REVERSED_CLIENT_ID"
echo "8. В поле 'Identifier' введите: GoogleSignIn"
echo "9. В поле 'Role' выберите: Editor"
echo ""
echo "Альтернативно, вы можете добавить следующие строки в Info.plist:"
echo ""
echo "<key>CFBundleURLTypes</key>"
echo "<array>"
echo "    <dict>"
echo "        <key>CFBundleURLName</key>"
echo "        <string>GoogleSignIn</string>"
echo "        <key>CFBundleURLSchemes</key>"
echo "        <array>"
echo "            <string>$REVERSED_CLIENT_ID</string>"
echo "        </array>"
echo "    </dict>"
echo "</array>"
echo ""
echo "✅ URL схема для Google Sign-In: $REVERSED_CLIENT_ID" 