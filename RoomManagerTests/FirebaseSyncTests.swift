import XCTest
@testable import RoomManager

class FirebaseSyncTests: XCTestCase {
    
    func testRoomConversion() {
        // Тест конвертации между локальной и Firebase моделями
        var localRoom = Room(number: "101") // <<< Изменено на var
        localRoom.color = .red
        localRoom.isMarked = true
        
        let firebaseRoom = FirebaseRoom(from: localRoom, deviceId: "test-device")
        XCTAssertEqual(firebaseRoom.number, "101")
        XCTAssertEqual(firebaseRoom.color, "red")
        XCTAssertTrue(firebaseRoom.isMarked)
        
        let convertedBack = firebaseRoom.toLocalRoom()
        XCTAssertEqual(convertedBack.number, localRoom.number)
        XCTAssertEqual(convertedBack.color, localRoom.color)
        XCTAssertEqual(convertedBack.isMarked, localRoom.isMarked)
    }
    
    func testConflictResolution() {
        var localRoom = Room(number: "101")
        localRoom.color = .red
        
        var remoteRoom = Room(number: "101")
        remoteRoom.color = .green
        
        let resolved = SyncConflictResolver.resolveConflict(
            localRoom: localRoom,
            remoteRoom: remoteRoom,
            strategy: .merge
        )
        
        // При merge стратегии, зеленый имеет более высокий приоритет
        XCTAssertEqual(resolved.color, .green)
    }
} 