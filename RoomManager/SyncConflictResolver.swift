import Foundation

class SyncConflictResolver {
    
    enum ConflictResolutionStrategy {
        case lastWriteWins
        case merge
        case askUser
    }
    
    static func resolveConflict(
        localRoom: Room,
        remoteRoom: Room,
        strategy: ConflictResolutionStrategy = .lastWriteWins
    ) -> Room {
        switch strategy {
        case .lastWriteWins:
            // Простая стратегия: выбираем комнату с последним изменением
            // Для этого нужно добавить timestamp в модель Room
            return remoteRoom // Временно всегда выбираем удаленную версию
            
        case .merge:
            // Более сложная логика объединения
            var mergedRoom = localRoom
            
            // Приоритет отдаем более "продвинутому" статусу
            if roomColorPriority(remoteRoom.color) > roomColorPriority(localRoom.color) {
                mergedRoom.color = remoteRoom.color
            }
            
            // Объединяем временные метки
            mergedRoom.redTimestamp = mostRecent(localRoom.redTimestamp, remoteRoom.redTimestamp)
            mergedRoom.greenTimestamp = mostRecent(localRoom.greenTimestamp, remoteRoom.greenTimestamp)
            mergedRoom.blueTimestamp = mostRecent(localRoom.blueTimestamp, remoteRoom.blueTimestamp)
            
            // Объединяем флаги
            mergedRoom.isMarked = localRoom.isMarked || remoteRoom.isMarked
            mergedRoom.isDeepCleaned = localRoom.isDeepCleaned || remoteRoom.isDeepCleaned
            
            return mergedRoom
            
        case .askUser:
            // В реальном приложении здесь был бы UI для выбора
            return localRoom
        }
    }
    
    private static func roomColorPriority(_ color: Room.RoomColor) -> Int {
        switch color {
        case .none: return 0
        case .red: return 1
        case .purple: return 2
        case .green: return 3
        case .blue: return 4
        case .white: return 5
        }
    }
    
    private static func mostRecent(_ date1: Date?, _ date2: Date?) -> Date? {
        guard let d1 = date1 else { return date2 }
        guard let d2 = date2 else { return date1 }
        return d1 > d2 ? d1 : d2
    }
} 