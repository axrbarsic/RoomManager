import SwiftUI

// Структура для хранения данных о статистике этажа
struct StatsUIFloorStats: Identifiable {
    let id = UUID()
    let floor: Int
    let redRooms: Int
    let greenRooms: Int
    let blueRooms: Int
    let whiteRooms: Int
    let totalRooms: Int
    
    // Вычисляем приоритет этажа по количеству комнат разного цвета
    var priority: Int {
        return redRooms * 3 + (totalRooms - redRooms - greenRooms - blueRooms - whiteRooms) * 2 + whiteRooms
    }
}

// Структура для представления данных о статусе
struct StatsUIStatusData: Identifiable {
    let id = UUID()
    let color: Color
    let count: Int
    let total: Int
    
    var percentage: Double {
        Double(count) / Double(total)
    }
} 

// Структура для общей статистики по комнатам (заглушка)
struct RoomStats {
    // Пока оставим пустой, т.к. неизвестно, какие поля должны быть
    // Можно будет добавить поля по мере необходимости, например:
    // let totalRooms: Int
    // let redRooms: Int
    // let greenRooms: Int
    // ... и т.д.
} 