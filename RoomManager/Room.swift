import Foundation

struct Room: Identifiable, Codable, Equatable {
    var id = UUID()
    var number: String
    var color: RoomColor
    var availableTime: String?
    var redTimestamp: Date?
    var greenTimestamp: Date?
    var blueTimestamp: Date?
    var noneTimestamp: Date?
    var whiteTimestamp: Date?
    var isMarked: Bool = false
    var isCompletedBefore930: Bool = false
    var isDeepCleaned: Bool = false

    enum RoomColor: String, Codable, CaseIterable {
        case none
        case red
        case green
        case purple
        case blue
        case white
    }

    init(number: String) {
        self.number = number
        self.color = .none
        self.availableTime = nil
        self.redTimestamp = nil
        self.greenTimestamp = nil
        self.blueTimestamp = nil
        self.noneTimestamp = Date()
        self.whiteTimestamp = nil
        self.isCompletedBefore930 = false
        self.isDeepCleaned = false
    }
    
    // Реализация Equatable для корректного сравнения комнат
    static func == (lhs: Room, rhs: Room) -> Bool {
        lhs.id == rhs.id &&
        lhs.number == rhs.number &&
        lhs.color == rhs.color &&
        lhs.availableTime == rhs.availableTime &&
        lhs.redTimestamp == rhs.redTimestamp &&
        lhs.greenTimestamp == rhs.greenTimestamp &&
        lhs.blueTimestamp == rhs.blueTimestamp &&
        lhs.noneTimestamp == rhs.noneTimestamp &&
        lhs.whiteTimestamp == rhs.whiteTimestamp &&
        lhs.isMarked == rhs.isMarked &&
        lhs.isCompletedBefore930 == rhs.isCompletedBefore930 &&
        lhs.isDeepCleaned == rhs.isDeepCleaned
    }
}
