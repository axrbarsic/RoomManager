import Foundation

enum ActionType: String, Codable {
    case addRoom = "add"
    case changeStatus = "change"
    case markRoom = "mark"
    case completeRoom = "complete"
    case deepClean = "deepclean"
    case deleteRoom = "delete"
    // Новые типы для синхронизации
    case syncUpdate = "syncUpdate"
    case syncDelete = "syncDelete"
}

struct HistoryRecord: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let roomNumber: String
    let oldStatus: String
    let newStatus: String
    let actionType: ActionType
    
    // CodingKeys для правильного декодирования
    enum CodingKeys: String, CodingKey {
        case timestamp, roomNumber, oldStatus, newStatus, actionType
        // id исключается из кодирования, так как генерируется автоматически
    }
    
    init(roomNumber: String, oldStatus: String, newStatus: String, actionType: ActionType, timestamp: Date = Date()) {
        self.roomNumber = roomNumber
        self.oldStatus = oldStatus
        self.newStatus = newStatus
        self.actionType = actionType
        self.timestamp = timestamp
    }
    
    var description: String {
        switch actionType {
        case .addRoom:
            return "Добавлена комната \(roomNumber)"
        case .changeStatus:
            return "Комната \(roomNumber): \(oldStatus) → \(newStatus)"
        case .markRoom:
            return "Комната \(roomNumber) отмечена"
        case .completeRoom:
            return "Комната \(roomNumber) завершена до 9:30"
        case .deepClean:
            return "Комната \(roomNumber) глубокая уборка"
        case .deleteRoom:
            return "Удалена комната \(roomNumber)"
        case .syncUpdate:
            return "Синхронизация: обновлена комната \(roomNumber)"
        case .syncDelete:
            return "Синхронизация: удалена комната \(roomNumber)"
        }
    }
}
