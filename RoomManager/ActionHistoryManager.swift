import Foundation

/// Простая запись действия в истории
struct SimpleActionRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let actionType: SimpleActionType
    let roomNumber: String?
    let description: String
    let beforeSnapshot: [Room]
    let afterSnapshot: [Room]
    
    init(id: UUID = UUID(), timestamp: Date = Date(), actionType: SimpleActionType, roomNumber: String?, description: String, beforeSnapshot: [Room], afterSnapshot: [Room]) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.roomNumber = roomNumber
        self.description = description
        self.beforeSnapshot = beforeSnapshot
        self.afterSnapshot = afterSnapshot
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    var shortDescription: String {
        return description.count > 50 ? String(description.prefix(47)) + "..." : description
    }
}

/// Простые типы действий - без лишней сложности
enum SimpleActionType: String, Codable, CaseIterable {
    case addRoom = "add"           // Добавить комнату
    case deleteRoom = "delete"     // Удалить комнату  
    case changeStatus = "status"   // Изменить статус
    case toggleMark = "mark"       // Переключить метку
    case setTime = "time"          // Установить время
    case clearAll = "clear"        // Очистить все
    case deepClean = "deep"        // Deep Clean операции
    case systemChange = "system"   // Изменения фильтров, layout и других системных настроек
    
    var icon: String {
        switch self {
        case .addRoom: return "plus.circle.fill"
        case .deleteRoom: return "minus.circle.fill" 
        case .changeStatus: return "paintbrush.fill"
        case .toggleMark: return "flag.fill"
        case .setTime: return "clock.fill"
        case .clearAll: return "trash.fill"
        case .deepClean: return "sparkles"
        case .systemChange: return "slider.horizontal.3"
        }
    }
    
    var color: String {
        switch self {
        case .addRoom: return "green"
        case .deleteRoom: return "red"
        case .changeStatus: return "orange" 
        case .toggleMark: return "blue"
        case .setTime: return "purple"
        case .clearAll: return "pink"
        case .deepClean: return "indigo"
        case .systemChange: return "gray"
        }
    }
}

/// Простой и четкий менеджер истории - без всякой фигни!
class SimpleHistoryManager: ObservableObject {
    static let shared = SimpleHistoryManager()
    
    @Published var history: [SimpleActionRecord] = []
    private let maxHistorySize = 10 // Жестко ограничиваем 10 записями!
    
    private init() {
        loadHistory()
    }
    
    /// Записать действие в историю - просто и ясно!
    func recordAction(
        type: SimpleActionType,
        description: String,
        roomNumber: String? = nil,
        beforeState: [Room],
        afterState: [Room]
    ) {
        let record = SimpleActionRecord(
            actionType: type,
            roomNumber: roomNumber,
            description: description,
            beforeSnapshot: beforeState,
            afterSnapshot: afterState
        )
        
        // Добавляем в начало списка
        history.insert(record, at: 0)
        
        // Безжалостно обрезаем до 10 записей
        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }
        
        saveHistory()
        print("🎯 ИСТОРИЯ: \(description)")
    }
    
    /// Отменить последнее действие - как удар назад!
    func undoLastAction() -> [Room]? {
        guard !history.isEmpty else { 
            print("❌ Нечего отменять!")
            return nil 
        }
        
        let lastRecord = history.removeFirst()
        saveHistory()
        
        print("⏪ ОТМЕНА: \(lastRecord.description)")
        return lastRecord.beforeSnapshot
    }
    
    /// Получить последнее действие
    func getLastAction() -> SimpleActionRecord? {
        return history.first
    }
    
    /// Очистить всю историю - табула раса!
    func clearHistory() {
        history.removeAll()
        saveHistory()
        print("🧹 История очищена!")
    }
    
    /// Получить статистику изменений
    func getChangeStats() -> (total: Int, byType: [SimpleActionType: Int]) {
        var stats: [SimpleActionType: Int] = [:]
        
        for type in SimpleActionType.allCases {
            stats[type] = history.filter { $0.actionType == type }.count
        }
        
        return (total: history.count, byType: stats)
    }
    
    // MARK: - Сохранение/загрузка
    
    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history),
              let url = getHistoryURL() else {
            print("⚠️ Не удалось сохранить историю")
            return
        }
        
        try? data.write(to: url)
    }
    
    private func loadHistory() {
        guard let url = getHistoryURL(),
              let data = try? Data(contentsOf: url),
              let loadedHistory = try? JSONDecoder().decode([SimpleActionRecord].self, from: data) else {
            history = []
            return
        }
        
        // Ограничиваем загруженную историю до 10 записей
        history = Array(loadedHistory.prefix(maxHistorySize))
        print("📚 Загружено \(history.count) записей истории")
    }
    
    private func getHistoryURL() -> URL? {
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("simple_history.json")
    }
}

// MARK: - Удобные методы для записи действий

extension SimpleHistoryManager {
    
    func recordAddRoom(_ roomNumber: String, before: [Room], after: [Room]) {
        recordAction(
            type: .addRoom,
            description: "Добавлена комната \(roomNumber)",
            roomNumber: roomNumber,
            beforeState: before,
            afterState: after
        )
    }
    
    func recordDeleteRoom(_ roomNumber: String, before: [Room], after: [Room]) {
        recordAction(
            type: .deleteRoom,
            description: "Удалена комната \(roomNumber)",
            roomNumber: roomNumber,
            beforeState: before,
            afterState: after
        )
    }
    
    func recordStatusChange(_ roomNumber: String, from: Room.RoomColor, to: Room.RoomColor, before: [Room], after: [Room]) {
        let fromName = colorName(from)
        let toName = colorName(to)
        recordAction(
            type: .changeStatus,
            description: "Комната \(roomNumber): \(fromName) → \(toName)",
            roomNumber: roomNumber,
            beforeState: before,
            afterState: after
        )
    }
    
    func recordMarkToggle(_ roomNumber: String, marked: Bool, before: [Room], after: [Room]) {
        let action = marked ? "отмечена" : "снята метка"
        recordAction(
            type: .toggleMark,
            description: "Комната \(roomNumber) \(action)",
            roomNumber: roomNumber,
            beforeState: before,
            afterState: after
        )
    }
    
    func recordTimeSet(_ roomNumber: String, time: String?, before: [Room], after: [Room]) {
        let action = time != nil ? "установлено время \(time!)" : "удалено время"
        recordAction(
            type: .setTime,
            description: "Комната \(roomNumber): \(action)",
            roomNumber: roomNumber,
            beforeState: before,
            afterState: after
        )
    }
    
    func recordClearAll(before: [Room], after: [Room]) {
        recordAction(
            type: .clearAll,
            description: "Очищены все комнаты (\(before.count) → \(after.count))",
            beforeState: before,
            afterState: after
        )
    }
    
    func recordDeepClean(_ roomNumber: String, marked: Bool, before: [Room], after: [Room]) {
        let action = marked ? "помечена как Deep Clean" : "снята пометка Deep Clean"
        recordAction(
            type: .deepClean,
            description: "Комната \(roomNumber) \(action)",
            roomNumber: roomNumber,
            beforeState: before,
            afterState: after
        )
    }

    func recordSystemChange(_ description: String, before: [Room], after: [Room]) {
        recordAction(
            type: .systemChange,
            description: description,
            roomNumber: nil, // Нет конкретного номера комнаты
            beforeState: before,
            afterState: after
        )
    }
    
    private func colorName(_ color: Room.RoomColor) -> String {
        switch color {
        case .none: return "Желтый"
        case .red: return "Красный"
        case .green: return "Зеленый"
        case .blue: return "Синий"
        case .purple: return "Фиолетовый"
        case .white: return "Белый"
        }
    }
}

// MARK: - Совместимость со старым кодом (временный слой адаптации)

/// Временный адаптер для совместимости - убрать когда весь код будет переписан!
class ActionHistoryManager: ObservableObject {
    static let shared = ActionHistoryManager()
    
    @Published var actionHistory: [SimpleActionRecord] = []
    
    private let simpleHistory = SimpleHistoryManager.shared
    
    private init() {
        // Синхронизируем с новой системой
        actionHistory = simpleHistory.history
        
        // Подписываемся на изменения
        simpleHistory.$history.assign(to: &$actionHistory)
    }
    
    // MARK: - Методы-адаптеры для старого API
    
    func recordAddRoom(roomNumber: String, rooms: [Room]) {
        // Внимание! rooms - это состояние ДО добавления (передается из ContentView)
        // Нужно создать состояние ПОСЛЕ добавления
        let beforeState = rooms
        
        // Создаем новую комнату и добавляем ее к текущему состоянию
        let newRoom = Room(number: roomNumber)
        var afterState = rooms
        afterState.append(newRoom)
        
        simpleHistory.recordAddRoom(roomNumber, before: beforeState, after: afterState)
    }
    
    func recordDeleteRoom(roomNumber: String, prevColor: Room.RoomColor, rooms: [Room]) {
        // Создаем удаленную комнату и восстанавливаем предыдущее состояние
        var beforeState = rooms
        var deletedRoom = Room(number: roomNumber)
        deletedRoom.color = prevColor
        beforeState.append(deletedRoom)
        simpleHistory.recordDeleteRoom(roomNumber, before: beforeState, after: rooms)
    }
    
    func recordColorChange(roomNumber: String, prevColor: Room.RoomColor, newColor: Room.RoomColor, rooms: [Room]) {
        // Восстанавливаем предыдущее состояние
        var beforeState = rooms
        if let index = beforeState.firstIndex(where: { $0.number == roomNumber }) {
            beforeState[index].color = prevColor
        }
        simpleHistory.recordStatusChange(roomNumber, from: prevColor, to: newColor, before: beforeState, after: rooms)
    }
    
    func recordMark(roomNumber: String, beforeState: [Room], afterState: [Room]) {
        simpleHistory.recordMarkToggle(roomNumber, marked: true, before: beforeState, after: afterState)
    }
    
    func recordUnmark(roomNumber: String, beforeState: [Room], afterState: [Room]) {
        simpleHistory.recordMarkToggle(roomNumber, marked: false, before: beforeState, after: afterState)
    }
    
    func recordAddTime(roomNumber: String, time: Date, rooms: [Room]) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: time)
        
        var beforeState = rooms
        if let index = beforeState.firstIndex(where: { $0.number == roomNumber }) {
            beforeState[index].availableTime = nil
        }
        simpleHistory.recordTimeSet(roomNumber, time: timeString, before: beforeState, after: rooms)
    }
    
    func recordRemoveTime(roomNumber: String, prevTime: Date, rooms: [Room]) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: prevTime)
        
        var beforeState = rooms
        if let index = beforeState.firstIndex(where: { $0.number == roomNumber }) {
            beforeState[index].availableTime = timeString
        }
        simpleHistory.recordTimeSet(roomNumber, time: nil, before: beforeState, after: rooms)
    }
    
    func recordClearAll(rooms: [Room]) {
        // Для очистки всех - предыдущее состояние равно текущему
        simpleHistory.recordClearAll(before: rooms, after: [])
    }
    
    func recordRestore(rooms: [Room]) {
        simpleHistory.recordAction(
            type: .clearAll,
            description: "Восстановлены данные комнат (\(rooms.count) комнат)",
            beforeState: [],
            afterState: rooms
        )
    }
    
    func recordToggleWhiteRoomsVisibility(isHidden: Bool, rooms: [Room]) {
        let description = isHidden ? "Скрыты белые комнаты" : "Показаны белые комнаты"
        simpleHistory.recordSystemChange(description, before: rooms, after: rooms)
    }
    
    func recordFilterChange(name: String, description: String, rooms: [Room]) {
        simpleHistory.recordSystemChange(description, before: rooms, after: rooms)
    }
    
    func recordMarkDeepClean(roomNumber: String, beforeState: [Room], afterState: [Room]) {
        simpleHistory.recordDeepClean(roomNumber, marked: true, before: beforeState, after: afterState)
    }
    
    func recordUnmarkDeepClean(roomNumber: String, beforeState: [Room], afterState: [Room]) {
        simpleHistory.recordDeepClean(roomNumber, marked: false, before: beforeState, after: afterState)
    }
    
    func getLastAction() -> SimpleActionRecord? {
        return simpleHistory.getLastAction()
    }
    
    func getPreviousRoomsState() -> [Room]? {
        return simpleHistory.getLastAction()?.beforeSnapshot
    }
    
    func removeLastAction() {
        _ = simpleHistory.undoLastAction()
    }
    
    func getAllBackups() -> [SimpleActionRecord] {
        return simpleHistory.history
    }
    
    func clearHistory() {
        simpleHistory.clearHistory()
    }
    
    // Метод для добавления записи напрямую (для Firebase синхронизации)
    func addRecord(_ record: HistoryRecord) {
        // Конвертируем ActionType в SimpleActionType
        let simpleActionType: SimpleActionType
        switch record.actionType {
        case .addRoom:
            simpleActionType = .addRoom
        case .changeStatus:
            simpleActionType = .changeStatus
        case .markRoom:
            simpleActionType = .toggleMark
        case .completeRoom:
            simpleActionType = .toggleMark
        case .deepClean:
            simpleActionType = .deepClean
        case .deleteRoom:
            simpleActionType = .deleteRoom
        case .syncUpdate:
            simpleActionType = .systemChange
        case .syncDelete:
            simpleActionType = .systemChange
        }
        
        let simpleRecord = SimpleActionRecord(
            id: record.id,
            timestamp: record.timestamp,
            actionType: simpleActionType,
            roomNumber: record.roomNumber,
            description: record.description,
            beforeSnapshot: [], // Для Firebase записей нет снимков состояния
            afterSnapshot: []
        )
        simpleHistory.history.append(simpleRecord)
        // Используем прямое сохранение в UserDefaults
        if let data = try? JSONEncoder().encode(simpleHistory.history) {
            UserDefaults.standard.set(data, forKey: "actionHistory")
        }
    }
}

// MARK: - Дополнительные типы для совместимости

typealias ActionRecord = SimpleActionRecord

