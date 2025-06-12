#!/bin/bash

# Скрипт для временного изменения Bundle ID проекта на значение из GoogleService-Info.plist
# Запустите этот скрипт перед сборкой проекта, если у вас проблемы с несоответствием Bundle ID

# Поиск Info.plist в различных директориях
INFO_PLIST_CANDIDATES=(
    "./Info.plist"
    "../Info.plist"
    "./RoomManager/Info.plist"
    "../RoomManager/Info.plist"
)

INFO_PLIST=""
for candidate in "${INFO_PLIST_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
        INFO_PLIST="$candidate"
        break
    fi
done

if [ -z "$INFO_PLIST" ]; then
    echo "❌ Ошибка: Info.plist не найден автоматически"
    echo "📋 Инструкция: Вам необходимо изменить Bundle ID через Xcode:"
    echo "1. Откройте проект в Xcode"
    echo "2. Выберите проект в навигаторе проектов"
    echo "3. Выберите таргет RoomManager"
    echo "4. Перейдите на вкладку 'General'"
    echo "5. Найдите 'Bundle Identifier' и измените его на значение из GoogleService-Info.plist (обычно 'axr')"
    echo "6. Запустите приложение"
    exit 1
fi

# Путь к GoogleService-Info.plist
FIREBASE_PLIST="./GoogleService-Info.plist"

if [ ! -f "$FIREBASE_PLIST" ]; then
    echo "❌ Ошибка: GoogleService-Info.plist не найден в $FIREBASE_PLIST"
    exit 1
fi

# Получаем текущий Bundle ID из Info.plist
CURRENT_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Ошибка: Не удалось получить Bundle ID из Info.plist"
    exit 1
fi

# Получаем Firebase Bundle ID из GoogleService-Info.plist
FIREBASE_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$FIREBASE_PLIST" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Ошибка: Не удалось получить BUNDLE_ID из GoogleService-Info.plist"
    exit 1
fi

echo "📱 Текущий Bundle ID: $CURRENT_BUNDLE_ID"
echo "🔥 Firebase Bundle ID: $FIREBASE_BUNDLE_ID"

# Делаем резервную копию Info.plist
cp "$INFO_PLIST" "${INFO_PLIST}.backup"
echo "💾 Создана резервная копия Info.plist: ${INFO_PLIST}.backup"

# Изменяем Bundle ID в Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $FIREBASE_BUNDLE_ID" "$INFO_PLIST"
if [ $? -eq 0 ]; then
    echo "✅ Bundle ID успешно изменен на $FIREBASE_BUNDLE_ID"
else
    echo "❌ Ошибка при изменении Bundle ID"
    # Восстанавливаем из резервной копии
    cp "${INFO_PLIST}.backup" "$INFO_PLIST"
    exit 1
fi

echo "✅ Готово! После сборки не забудьте восстановить исходный Bundle ID:"
echo "   cp \"${INFO_PLIST}.backup\" \"$INFO_PLIST\""

exit 0 