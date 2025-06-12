#!/bin/bash

echo "=== ОТЛАДКА АВТОРИЗАЦИИ ROOM MANAGER ==="
echo "Время начала: $(date)"
echo

# Очистка логов
echo "1. Очищаем логи..."
adb logcat -c

# Запуск приложения
echo "2. Запускаем приложение..."
adb shell am start -n com.roommanager.android/.ui.MainActivity

echo "3. Начинаем отслеживание логов Firebase авторизации..."
echo "   Ищем: axrbarsic@gmail.com, Firebase, Auth, Error"
echo

# Логирование с фильтрацией
adb logcat -v time | grep -i -E "(firebase|auth|room|axrbarsic|error|exception|grpc|connection|ssl|network|signin|token|user)" --line-buffered | while read line; do
    echo "[$(date '+%H:%M:%S')] $line"
done 