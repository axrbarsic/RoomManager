import Foundation
import FirebaseFirestore

// MARK: - Firebase Room Model
struct FirebaseRoom: Codable {
    @DocumentID var id: String?
    var number: String
    var color: String
    var availableTime: String?
    var redTimestamp: Date?
    var greenTimestamp: Date?
    var blueTimestamp: Date?
    var noneTimestamp: Date?
    var whiteTimestamp: Date?
    var isMarked: Bool
    var isCompletedBefore930: Bool
    var isDeepCleaned: Bool
    var lastModified: Date
    var deviceId: String
    
    // Конвертация из локальной модели Room
    init(from room: Room, deviceId: String) {
        self.id = room.id.uuidString
        self.number = room.number
        self.color = room.color.rawValue
        self.availableTime = room.availableTime
        self.redTimestamp = room.redTimestamp
        self.greenTimestamp = room.greenTimestamp
        self.blueTimestamp = room.blueTimestamp
        self.noneTimestamp = room.noneTimestamp
        self.whiteTimestamp = room.whiteTimestamp
        self.isMarked = room.isMarked
        self.isCompletedBefore930 = room.isCompletedBefore930
        self.isDeepCleaned = room.isDeepCleaned
        self.lastModified = Date()
        self.deviceId = deviceId
    }
    
    // Конвертация в локальную модель Room
    func toLocalRoom() -> Room {
        var room = Room(number: self.number)
        if let id = self.id, let uuid = UUID(uuidString: id) {
            room.id = uuid
        }
        room.color = Room.RoomColor(rawValue: self.color) ?? .none
        room.availableTime = self.availableTime
        room.redTimestamp = self.redTimestamp
        room.greenTimestamp = self.greenTimestamp
        room.blueTimestamp = self.blueTimestamp
        room.noneTimestamp = self.noneTimestamp
        room.whiteTimestamp = self.whiteTimestamp
        room.isMarked = self.isMarked
        room.isCompletedBefore930 = self.isCompletedBefore930
        room.isDeepCleaned = self.isDeepCleaned
        return room
    }
}

// MARK: - Sync Metadata
struct SyncMetadata: Codable {
    @DocumentID var id: String?
    var lastSyncTimestamp: Date
    var deviceId: String
    var deviceName: String
} 