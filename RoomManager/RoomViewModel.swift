import Foundation
import SwiftUI
import UIKit
import Combine

private struct RVMColorCount: Identifiable {
    let id = UUID()
    let color: Room.RoomColor
    let count: Int
    let backgroundColor: Color
    let textColor: Color
}

class RoomViewModel: ObservableObject {
    @Published var rooms: [Room] = []
    private var timer: Timer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    @Published var language: Language = .ru {
        didSet { saveLanguage() }
    }
    @Published var history: [HistoryRecord] = []
    @Published var backups: [BackupRecord] = []
    @Published var hideWhiteRooms: Bool = false // Флаг для скрытия белых комнат
    
    // Менеджер этажей
    @ObservedObject var floorManager = FloorManager.shared
    
    // Свойства для отслеживания последних трех комнат с разным статусом
    @Published var lastThreeRedRooms: [UUID] = []
    @Published var lastThreeGreenRooms: [UUID] = []
    @Published var lastThreeBlueRooms: [UUID] = []

    // Добавьте новые свойства для Firebase
    private let firebaseManager = FirebaseManager.shared
    private var firebaseCancellables = Set<AnyCancellable>()
    private var syncDebouncer: Timer?

    // Флаг для предотвращения циклической синхронизации
    private var isUpdatingFromFirebase = false

    enum Language: String, CaseIterable, Codable {
        case ru = "Русский"
        case en = "English"
        case es = "Español"
        case ht = "Kreyòl"
    }

    struct BackupRecord: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let data: Data
        let name: String

        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: timestamp)
        }

        init(timestamp: Date, data: Data, name: String? = nil) {
            self.id = UUID()
            self.timestamp = timestamp
            self.data = data
            
            if let customName = name {
                self.name = customName
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy HH:mm"
                self.name = "Бэкап от \(formatter.string(from: timestamp))"
            }
        }
    }

    init() {
        loadRooms()
        loadLanguage()
        loadHistory()
        loadBackups()
        checkNewDayAndClearIfNeeded()
        startTimeChecking()
        setupNotificationObservers()
        updateLastThreeRedRooms()
        updateLastThreeGreenRooms()
        updateLastThreeBlueRooms()

        // Настройка Firebase
        setupFirebaseObservers()

        // Автоматическая аутентификация при запуске
        Task {
            try? await firebaseManager.signInAnonymously()
        }
    }
    
    deinit {
        stopTimeChecking()
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
            
        NotificationCenter.default.addObserver(self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopTimeChecking()
            if let backgroundTask = self?.backgroundTask, backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                self?.backgroundTask = .invalid
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        checkPurpleRooms()
        startTimeChecking()
    }
    
    private func startTimeChecking() {
        stopTimeChecking() // Останавливаем предыдущий таймер если он существует
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkPurpleRooms()
        }
        timer?.tolerance = 5 // Добавляем небольшую погрешность для оптимизации энергопотребления
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func stopTimeChecking() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkPurpleRooms() {
        let calendar = Calendar.current
        let now = Date()
        
        var needsSaving = false
        
        for index in rooms.indices {
            if rooms[index].color == .purple,
               let availableTimeString = rooms[index].availableTime {
                
                // Парсим время из строки
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                
                if let targetTime = formatter.date(from: availableTimeString) {
                    // Создаем компоненты даты для сравнения только времени
                    let targetComponents = calendar.dateComponents([.hour, .minute], from: targetTime)
                    
                    // Создаем даты с сегодняшним днем для корректного сравнения
                    var targetDateComponents = calendar.dateComponents([.year, .month, .day], from: now)
                    targetDateComponents.hour = targetComponents.hour
                    targetDateComponents.minute = targetComponents.minute
                    
                    if let targetDate = calendar.date(from: targetDateComponents),
                       now >= targetDate {
                        rooms[index].color = .red
                        rooms[index].redTimestamp = now
                        needsSaving = true
                    }
                }
            }
        }
        
        if needsSaving {
            saveRooms()
        }
    }

    func addRoom(number: String) -> String? {
        guard isValidRoomNumber(number) else {
            if number.hasSuffix("29") {
                return getTranslation(for: "easterEgg")
            }
            return getTranslation(for: "errorInvalidNumber")
        }
        if rooms.contains(where: { $0.number == number }) {
            return getTranslation(for: "errorDuplicate")
        }
        rooms.append(Room(number: number))
        saveRooms()
        return nil
    }

    func clearAllRooms() {
        saveHistoryIfNeeded()
        rooms.removeAll()
        saveRooms()

        // Также очищаем в Firebase
        Task {
            try? await firebaseManager.clearAllRooms()
        }
    }

    func loadRooms() {
        if let data = UserDefaults.standard.data(forKey: "rooms"),
           let saved = try? JSONDecoder().decode([Room].self, from: data) {
            rooms = saved
            
            // Миграция данных: устанавливаем noneTimestamp для желтых комнат без временной метки
            var needsSaving = false
            let now = Date()
            
            for i in 0..<rooms.count {
                if rooms[i].color == .none && rooms[i].noneTimestamp == nil {
                    rooms[i].noneTimestamp = now
                    needsSaving = true
                }
            }
            
            // Сохраняем только если были изменения
            if needsSaving {
                saveRooms()
            }
        }
    }

    func saveRooms() {
        saveRoomsLocally()

        // Синхронизируем с Firebase с задержкой (debounce)
        if !isUpdatingFromFirebase {
            scheduleSyncWithFirebase()
        }
    }

    func saveRoomsLocally() {
        withAnimation(.none) { // Отключаем анимацию при сохранении комнат
            let roomsData = try? JSONEncoder().encode(rooms)
            UserDefaults.standard.set(roomsData, forKey: "rooms")
            
            // Также сохраняем историю
            saveHistoryIfNeeded()
        }
        
        // Обновляем списки последних трех комнат разных цветов
        updateLastThreeRedRooms()
        updateLastThreeGreenRooms()
        updateLastThreeBlueRooms()
    }

    // Метод для обновления списка последних трех красных комнат
    private func updateLastThreeRedRooms() {
        // Получаем все красные комнаты, сортируем по времени (если есть) или просто берем последние
        let redRooms = rooms.filter { $0.color == .red }
        
        // Сортируем по времени, если доступно
        let sortedRedRooms = redRooms.sorted { room1, room2 in
            guard let time1 = room1.redTimestamp else { return false }
            guard let time2 = room2.redTimestamp else { return true }
            return time1 > time2
        }
        
        // Берем только последние три
        lastThreeRedRooms = sortedRedRooms.prefix(3).map { $0.id }
    }
    
    // Метод для обновления списка последних трех зеленых комнат
    private func updateLastThreeGreenRooms() {
        // Получаем все зеленые комнаты, сортируем по времени (если есть) или просто берем последние
        let greenRooms = rooms.filter { $0.color == .green }
        
        // Сортируем по времени, если доступно
        let sortedGreenRooms = greenRooms.sorted { room1, room2 in
            guard let time1 = room1.greenTimestamp else { return false }
            guard let time2 = room2.greenTimestamp else { return true }
            return time1 > time2
        }
        
        // Берем только последние три
        lastThreeGreenRooms = sortedGreenRooms.prefix(3).map { $0.id }
    }
    
    // Метод для обновления списка последних трех синих комнат
    private func updateLastThreeBlueRooms() {
        // Получаем все синие комнаты
        let blueRooms = rooms.filter { $0.color == .blue }
        
        // Синие комнаты сортируем по времени изменения на зеленый (так как синий идёт после зеленого)
        let sortedBlueRooms = blueRooms.sorted { room1, room2 in
            guard let time1 = room1.greenTimestamp else { return false }
            guard let time2 = room2.greenTimestamp else { return true }
            return time1 > time2
        }
        
        // Берем только последние три
        lastThreeBlueRooms = sortedBlueRooms.prefix(3).map { $0.id }
    }

    // Метод для проверки, является ли комната одной из последних трех красных комнат
    func isInLastThreeRedRooms(roomID: UUID) -> Bool {
        return lastThreeRedRooms.contains(roomID)
    }
    
    // Метод для проверки, является ли комната одной из последних трех зеленых комнат
    func isInLastThreeGreenRooms(roomID: UUID) -> Bool {
        return lastThreeGreenRooms.contains(roomID)
    }
    
    // Метод для проверки, является ли комната одной из последних трех синих комнат
    func isInLastThreeBlueRooms(roomID: UUID) -> Bool {
        return lastThreeBlueRooms.contains(roomID)
    }

    func getTranslation(for key: String) -> String {
        Translations.translations[language]?[key] ?? key
    }

    private func checkNewDayAndClearIfNeeded() {
        let today = startOfToday()
        let lastDay = UserDefaults.standard.object(forKey: "lastActiveDay") as? Date
        if let last = lastDay, last != today {
            clearAllRooms()
        } else if lastDay == nil {
            // Первый запуск
        }
        UserDefaults.standard.set(today, forKey: "lastActiveDay")
    }

    private func isValidRoomNumber(_ number: String) -> Bool {
        generateValidRoomNumbers().contains(number)
    }

    private func generateValidRoomNumbers() -> Set<String> {
        var numbers = Set<String>()
        for floor in [1,2,3,4,5] {
            for num in 1...30 {
                if num != 29 {
                    let roomNumber = "\(floor)\(String(format: "%02d", num))"
                    numbers.insert(roomNumber)
                }
            }
        }
        return numbers
    }

    private func saveHistoryIfNeeded() {
        // Новая структура HistoryRecord не поддерживает сохранение всех комнат за день
        // Эта функция больше не актуальна, так как история теперь хранит отдельные действия
        // Оставляем пустую реализацию
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "history"),
           let saved = try? JSONDecoder().decode([HistoryRecord].self, from: data) {
            history = saved
        }
    }

    private func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func saveLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: "language")
    }

    private func loadLanguage() {
        if let saved = UserDefaults.standard.string(forKey: "language"),
           let lang = Language(rawValue: saved) {
            language = lang
        }
    }

    private func loadBackups() {
        if let data = UserDefaults.standard.data(forKey: "backups"),
           let saved = try? JSONDecoder().decode([BackupRecord].self, from: data) {
            backups = saved
        }
    }

    func saveBackups() {
        if let data = try? JSONEncoder().encode(backups) {
            UserDefaults.standard.set(data, forKey: "backups")
        }
    }

    // MARK: - Backup and Restore Methods

    func backupRooms() -> String {
        // Создаем бэкап с датой/временем
        if let data = try? JSONEncoder().encode(rooms) {
            // Создаем имя бэкапа на основе текущей даты
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd.MM.yyyy HH:mm"
            let dateString = dateFormatter.string(from: Date())
            let backupName = "Бэкап от \(dateString)"
            
            let newBackup = BackupRecord(timestamp: Date(), data: data, name: backupName)
            backups.append(newBackup)
            saveBackups()
            
            // Ограничиваем количество сохраняемых бэкапов до 10
            if backups.count > 10 {
                backups = Array(backups.sorted { $0.timestamp > $1.timestamp }.prefix(10))
                saveBackups()
            }
            
            return getTranslation(for: "backupCreated")
        }
        return getTranslation(for: "backupError")
    }

    func restoreRooms(from backup: BackupRecord) -> String {
        // Восстанавливаем из выбранного бэкапа
        if let restored = try? JSONDecoder().decode([Room].self, from: backup.data) {
            rooms = restored
            saveRooms()
            return getTranslation(for: "restoreSuccess") 
        } else {
            return getTranslation(for: "restoreInvalidFile")
        }
    }

    private func getSortedColorCounts() -> [RVMColorCount] {
        // Используем только комнаты с активных этажей
        let activeFloorRooms = filteredRoomsByFloor
        
        var counts = [
            RVMColorCount(
                color: .none,
                count: activeFloorRooms.filter { $0.color == .none }.count,
                backgroundColor: Color.yellow.opacity(0.85),
                textColor: .black
            ),
            RVMColorCount(
                color: .red,
                count: activeFloorRooms.filter { $0.color == .red }.count,
                backgroundColor: Color.red,
                textColor: .white
            ),
            RVMColorCount(
                color: .green,
                count: activeFloorRooms.filter { $0.color == .green }.count,
                backgroundColor: Color.green,
                textColor: .black
            ),
            RVMColorCount(
                color: .blue,
                count: activeFloorRooms.filter { $0.color == .blue }.count,
                backgroundColor: Color.blue,
                textColor: .white
            ),
            RVMColorCount(
                color: .purple,
                count: activeFloorRooms.filter { $0.color == .purple }.count,
                backgroundColor: Color.purple,
                textColor: .white
            )
        ]
        
        // Добавляем белые комнаты только если они не скрыты
        if !hideWhiteRooms {
            counts.append(
                RVMColorCount(
                    color: .white,
                    count: activeFloorRooms.filter { $0.color == .white }.count,
                    backgroundColor: Color.white,
                    textColor: .black
                )
            )
        }
        
        return counts.sorted { $0.count < $1.count }
    }

    // Метод для отметки комнаты как сделанной до 9:30
    func toggleCompletedBefore930(roomId: UUID) {
        if let index = rooms.firstIndex(where: { $0.id == roomId }) {
            // Получаем предыдущее состояние флага и цвета
            let _ = rooms[index].isCompletedBefore930
            let previousColor = rooms[index].color
            let _ = rooms[index].isMarked
            
            // Переключаем состояние
            rooms[index].isCompletedBefore930.toggle()
            
            // Если отмечаем как "сделанную до 9:30", меняем цвет на белый
            if rooms[index].isCompletedBefore930 {
                // Сохраняем предыдущий цвет и устанавливаем белый
                rooms[index].color = .white
                
                // Если комната была отмечена, сбрасываем метку
                if rooms[index].isMarked {
                    let beforeMarkState = rooms
                    rooms[index].isMarked = false
                    let afterMarkState = rooms
                    // Записываем действие снятия метки в историю
                    ActionHistoryManager.shared.recordUnmark(
                        roomNumber: rooms[index].number,
                        beforeState: beforeMarkState,
                        afterState: afterMarkState
                    )
                }
                
                // Записываем действие изменения цвета в историю
                ActionHistoryManager.shared.recordColorChange(
                    roomNumber: rooms[index].number,
                    prevColor: previousColor,
                    newColor: .white,
                    rooms: rooms
                )
                
                // Записываем действие отметки в историю (заглушка для совместимости)
                // В действительности здесь мы устанавливаем белый цвет и флаг completed930
                // Историю уже записал вызов recordColorChange выше
            } else {
                // Возвращаем комнату к предыдущему цвету (если она была белой, устанавливаем .none)
                rooms[index].color = previousColor == .white ? .none : previousColor
                
                // Записываем действие изменения цвета в историю
                ActionHistoryManager.shared.recordColorChange(
                    roomNumber: rooms[index].number,
                    prevColor: .white,
                    newColor: rooms[index].color,
                    rooms: rooms
                )
                
                // Записываем действие снятия отметки в историю (заглушка для совместимости)
                // В действительности здесь мы убираем белый цвет и флаг completed930
                // Историю уже записал вызов recordColorChange выше
            }
            
            // Сохраняем изменения
            saveRooms()
        }
    }
    
    // Метод для отметки комнаты как "Deep Cleaned"
    func toggleDeepCleaned(roomId: UUID) {
        if let index = rooms.firstIndex(where: { $0.id == roomId }) {
            let beforeState = rooms // Сохраняем состояние ДО изменения
            rooms[index].isDeepCleaned.toggle()
            let afterState = rooms // Состояние ПОСЛЕ изменения
            saveRooms()
            
            // Записываем действие в историю
            if rooms[index].isDeepCleaned {
                ActionHistoryManager.shared.recordMarkDeepClean(
                    roomNumber: rooms[index].number, 
                    beforeState: beforeState,
                    afterState: afterState
                )
            } else {
                ActionHistoryManager.shared.recordUnmarkDeepClean(
                    roomNumber: rooms[index].number, 
                    beforeState: beforeState,
                    afterState: afterState
                )
            }
        }
    }
    
    // Метод для получения комнат, исключая отмеченные как "до 9:30"
    func getRoomsExcludingBefore930() -> [Room] {
        return rooms.filter { !$0.isCompletedBefore930 }
    }
    
    // MARK: - Floor Filtering
    
    /// Возвращает комнаты только с активных этажей
    var filteredRoomsByFloor: [Room] {
        return rooms.filter { room in
            room.isOnActiveFloor
        }
    }
    
    /// Возвращает видимые комнаты (с учетом фильтра этажей и скрытия белых комнат)
    var visibleRooms: [Room] {
        var filtered = filteredRoomsByFloor
        
        if hideWhiteRooms {
            filtered = filtered.filter { $0.color != .white }
        }
        
        return filtered
    }

    // Метод для переключения видимости белых комнат
    func toggleWhiteRoomsVisibility() {
        hideWhiteRooms.toggle()
        
        // Записываем действие в историю
        ActionHistoryManager.shared.recordToggleWhiteRoomsVisibility(
            isHidden: hideWhiteRooms,
            rooms: rooms
        )
        
        // Обновляем UI с анимацией
        objectWillChange.send()
    }

    static func getTranslations() -> [String: [String: String]] {
        return [:] // Возвращаем пустой словарь, т.к. все переводы перенесены в Translations.swift
    }

    func getStats() -> RoomStats {
        // ... (существующий код getStats) -> Заменено на возврат заглушки
        return RoomStats() // Возвращаем заглушку, т.к. оригинальная реализация и использования не найдены
    }

    // MARK: - Demo Mode Action
    func performRandomRoomAction() {
        guard !rooms.isEmpty || Bool.random() else { // Если комнат нет, с 50% шансом попытаемся добавить новую
            // Попытка добавить новую комнату, если список пуст или по случайности
            let randomRoomNumber = String(Int.random(in: 100...599))
            _ = addRoom(number: randomRoomNumber) // Результат нам здесь не важен
            return
        }

        let actionType = Int.random(in: 0...3)

        switch actionType {
        case 0: // Добавить новую комнату (даже если уже есть другие)
            let randomRoomNumber = String(Int.random(in: 100...599))
            _ = addRoom(number: randomRoomNumber)
        case 1: // Удалить случайную комнату
            if let roomToRemove = rooms.randomElement(), let index = rooms.firstIndex(where: { $0.id == roomToRemove.id }) {
                rooms.remove(at: index)
                saveRooms()
            }
        case 2: // Изменить цвет случайной комнаты
            if let roomToChange = rooms.randomElement(), let index = rooms.firstIndex(where: { $0.id == roomToChange.id }) {
                let oldColor = rooms[index].color
                let newColor = Room.RoomColor.allCases.filter { $0 != oldColor }.randomElement() ?? .none // Избегаем того же цвета
                rooms[index].color = newColor
                // Обновляем временные метки, если нужно (упрощенно)
                if newColor == .red { rooms[index].redTimestamp = Date() } 
                else if newColor == .green { rooms[index].greenTimestamp = Date() }
                saveRooms()
            }
        case 3: // Пометить/снять пометку со случайной комнаты
            if let roomToMark = rooms.randomElement(), let index = rooms.firstIndex(where: { $0.id == roomToMark.id }) {
                rooms[index].isMarked.toggle()
                saveRooms()
            }
        default:
            break
        }
    }

    // MARK: - Firebase Setup

    private func setupFirebaseObservers() {
        // Удаляем старые наблюдатели, если они есть
        NotificationCenter.default.removeObserver(self, name: .roomUpdatedFromFirebase, object: nil)
        NotificationCenter.default.removeObserver(self, name: .roomDeletedFromFirebase, object: nil)
        
        // Добавляем наблюдатель за обновлениями комнат
        NotificationCenter.default.addObserver(
            forName: .roomUpdatedFromFirebase,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let room = notification.userInfo?["room"] as? Room {
                print("📱 Получено обновление комнаты из Firebase: \(room.number)")
                
                // Проверяем, существует ли комната с таким же id
                if let index = self.rooms.firstIndex(where: { $0.id == room.id }) {
                    // Обновляем существующую комнату
                    print("🔄 Обновляем существующую комнату: \(room.number)")
                    self.rooms[index] = room
                } else {
                    // Добавляем новую комнату
                    print("➕ Добавляем новую комнату из Firebase: \(room.number)")
                    self.rooms.append(room)
                    self.saveRooms()
                }
                
                // Обновляем историю изменений
                self.addHistoryRecord(room: room, actionType: .syncUpdate)
            }
        }
        
        // Добавляем наблюдатель за удалением комнат
        NotificationCenter.default.addObserver(
            forName: .roomDeletedFromFirebase,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            if let roomId = notification.userInfo?["roomId"] as? String,
               let uuid = UUID(uuidString: roomId),
               let index = self.rooms.firstIndex(where: { $0.id == uuid }) {
                
                let room = self.rooms[index]
                print("🗑️ Удаляем комнату из локальной базы: \(room.number)")
                
                // Удаляем комнату
                self.rooms.remove(at: index)
                self.saveRooms()
                
                // Обновляем историю изменений
                self.addHistoryRecord(room: room, actionType: .syncDelete)
            }
        }
        
        print("✅ Наблюдатели за Firebase настроены")
    }
    
    // Метод для загрузки данных из Firebase
    private func loadFromFirebase() async {
        do {
            let remoteRooms = try await firebaseManager.fetchRooms()
            
            // Переключаемся на главный поток для обновления UI
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if remoteRooms.isEmpty {
                    print("📊 Firebase: Нет комнат для загрузки")
                    // Если в Firebase нет комнат, но у нас есть локальные, отправляем их в Firebase
                    if !self.rooms.isEmpty {
                        print("📤 Отправляем локальные комнаты в Firebase: \(self.rooms.count)")
                        Task {
                            await self.syncToFirebase()
                        }
                    }
                    return
                }
                
                print("📥 Загружено из Firebase: \(remoteRooms.count) комнат")
                
                // Объединяем данные с существующими
                self.mergeRoomsFromFirebase(remoteRooms)
            }
        } catch {
            print("❌ Ошибка загрузки из Firebase: \(error)")
        }
    }
    
    // Новый метод для объединения данных из Firebase с локальными
    private func mergeRoomsFromFirebase(_ remoteRooms: [Room]) {
        print("🔄 Объединение данных из Firebase с локальными")
        
        // Для каждой удаленной комнаты
        for remoteRoom in remoteRooms {
            // Ищем локальную комнату с таким же id
            if let index = rooms.firstIndex(where: { $0.id == remoteRoom.id }) {
                // Обновляем существующую комнату
                print("🔄 Обновляем локальную комнату: \(remoteRoom.number)")
                rooms[index] = remoteRoom
            } else {
                // Добавляем новую комнату
                print("➕ Добавляем новую комнату из Firebase: \(remoteRoom.number)")
                rooms.append(remoteRoom)
            }
        }
        
        // Сохраняем обновленные комнаты
        saveRooms()
    }
    
    // Добавляем новый тип действия в историю для отслеживания синхронизации
    private func addHistoryRecord(room: Room, actionType: ActionType) {
        let record = HistoryRecord(
            roomNumber: room.number,
            oldStatus: room.color.rawValue,
            newStatus: room.color.rawValue,
            actionType: actionType
        )
        
        ActionHistoryManager.shared.addRecord(record)
    }
    
    // Метод для принудительной синхронизации с Firebase
    func syncToFirebase() async {
        await firebaseManager.syncRooms(rooms)
    }

    private func scheduleSyncWithFirebase() {
        syncDebouncer?.invalidate()
        syncDebouncer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            Task {
                await self.firebaseManager.syncRooms(self.rooms)
            }
        }
    }
}
