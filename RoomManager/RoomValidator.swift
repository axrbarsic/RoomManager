import Foundation

/// Валидатор для проверки данных комнат
struct RoomValidator {
    
    // MARK: - Validation Result
    enum ValidationResult {
        case valid
        case invalid(reason: String)
        
        var isValid: Bool {
            switch self {
            case .valid: return true
            case .invalid: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .valid: return nil
            case .invalid(let reason): return reason
            }
        }
    }
    
    // MARK: - Room Number Validation
    static func validateRoomNumber(_ roomNumber: String) -> ValidationResult {
        // Проверка на пустоту
        guard !roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(reason: "Номер комнаты не может быть пустым")
        }
        
        let trimmedNumber = roomNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Проверка длины
        guard trimmedNumber.count == AppConfiguration.Validation.maxRoomNumberLength else {
            return .invalid(reason: "Номер комнаты должен содержать ровно 3 цифры")
        }
        
        // Проверка формата (только цифры)
        guard trimmedNumber.allSatisfy({ $0.isNumber }) else {
            return .invalid(reason: "Номер комнаты должен содержать только цифры")
        }
        
        // Проверка паттерна (1-5XX, где XX = 01-30, исключая 29)
        guard let regex = try? NSRegularExpression(pattern: AppConfiguration.Validation.roomNumberPattern) else {
            return .invalid(reason: "Ошибка валидации формата")
        }
        
        let range = NSRange(location: 0, length: trimmedNumber.utf16.count)
        guard regex.firstMatch(in: trimmedNumber, range: range) != nil else {
            return .invalid(reason: "Неверный формат номера комнаты (должен быть от 101 до 530)")
        }
        
        // Проверка на исключенный номер 29
        if trimmedNumber.hasSuffix("29") {
            return .invalid(reason: "Номера комнат, заканчивающиеся на 29, не допускаются")
        }
        
        // Дополнительная проверка диапазона этажа и номера
        let floor = Int(trimmedNumber.prefix(1)) ?? 0
        let roomNum = Int(trimmedNumber.suffix(2)) ?? 0
        
        guard AppConfiguration.Rooms.floorRange.contains(floor) else {
            return .invalid(reason: "Этаж должен быть от 1 до 5")
        }
        
        guard AppConfiguration.Rooms.validRoomRange.contains(roomNum) else {
            return .invalid(reason: "Номер комнаты должен быть от 01 до 30")
        }
        
        guard roomNum != AppConfiguration.Rooms.excludedRoomNumber else {
            return .invalid(reason: "Номер 29 не допускается")
        }
        
        return .valid
    }
    
    // MARK: - Duplicate Check
    static func validateUniqueRoomNumber(_ roomNumber: String, in rooms: [Room]) -> ValidationResult {
        let trimmedNumber = roomNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !rooms.contains(where: { $0.number == trimmedNumber }) else {
            return .invalid(reason: "Комната с таким номером уже существует")
        }
        
        return .valid
    }
    
    // MARK: - Combined Validation
    static func validateNewRoom(roomNumber: String, existingRooms: [Room]) -> ValidationResult {
        // Проверяем формат номера
        let formatValidation = validateRoomNumber(roomNumber)
        guard formatValidation.isValid else {
            return formatValidation
        }
        
        // Проверяем уникальность
        let uniqueValidation = validateUniqueRoomNumber(roomNumber, in: existingRooms)
        guard uniqueValidation.isValid else {
            return uniqueValidation
        }
        
        return .valid
    }
    
    // MARK: - Time Validation
    static func validateTimeSelection(_ date: Date) -> ValidationResult {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Проверяем, что время в разрешенных границах (например, рабочие часы)
        guard (6...23).contains(hour) else {
            return .invalid(reason: "Время должно быть между 6:00 и 23:59")
        }
        
        // Проверяем, что минуты кратны 15
        guard AppConfiguration.Time.timePickerMinutes.contains(minute) else {
            return .invalid(reason: "Минуты должны быть кратны 15")
        }
        
        return .valid
    }
    
    // MARK: - Room State Validation
    static func validateRoomColorTransition(from currentColor: Room.RoomColor, to newColor: Room.RoomColor) -> ValidationResult {
        // Можно добавить бизнес-логику для допустимых переходов между состояниями
        // Например, нельзя перейти из красного сразу в синий, только через зеленый
        
        // Пока разрешаем все переходы
        return .valid
    }
    
    // MARK: - Batch Validation
    static func validateRoomNumbers(_ roomNumbers: [String]) -> [String: ValidationResult] {
        var results: [String: ValidationResult] = [:]
        
        for roomNumber in roomNumbers {
            results[roomNumber] = validateRoomNumber(roomNumber)
        }
        
        // Дополнительная проверка на дубликаты в самом массиве
        let duplicates = Dictionary(grouping: roomNumbers, by: { $0 })
            .filter { $1.count > 1 }
            .keys
        
        for duplicate in duplicates {
            results[duplicate] = .invalid(reason: "Дублированный номер в списке")
        }
        
        return results
    }
} 