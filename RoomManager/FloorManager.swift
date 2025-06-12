import Foundation
import SwiftUI

/// Менеджер для управления видимостью этажей
class FloorManager: ObservableObject {
    static let shared = FloorManager()
    
    @Published var activeFloors: Set<Int> = [] {
        didSet {
            saveActiveFloors()
        }
    }
    
    private let activeFloorsKey = "activeFloors"
    
    private init() {
        loadActiveFloors()
    }
    
    /// Загружает активные этажи из UserDefaults
    private func loadActiveFloors() {
        if let data = UserDefaults.standard.data(forKey: activeFloorsKey),
           let floors = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            activeFloors = floors
        } else {
            // По умолчанию все этажи активны
            activeFloors = Set(AppConfiguration.Rooms.allFloors)
        }
    }
    
    /// Сохраняет активные этажи в UserDefaults
    private func saveActiveFloors() {
        if let data = try? JSONEncoder().encode(activeFloors) {
            UserDefaults.standard.set(data, forKey: activeFloorsKey)
        }
    }
    
    /// Проверяет, активен ли этаж
    func isFloorActive(_ floor: Int) -> Bool {
        return activeFloors.contains(floor)
    }
    
    /// Переключает состояние этажа
    func toggleFloor(_ floor: Int) {
        if activeFloors.contains(floor) {
            activeFloors.remove(floor)
        } else {
            activeFloors.insert(floor)
        }
    }
    
    /// Включает этаж
    func enableFloor(_ floor: Int) {
        activeFloors.insert(floor)
    }
    
    /// Отключает этаж
    func disableFloor(_ floor: Int) {
        activeFloors.remove(floor)
    }
    
    /// Включает все этажи
    func enableAllFloors() {
        activeFloors = Set(AppConfiguration.Rooms.allFloors)
    }
    
    /// Отключает все этажи
    func disableAllFloors() {
        activeFloors.removeAll()
    }
    
    /// Проверяет, принадлежит ли комната активному этажу
    func isRoomOnActiveFloor(_ roomNumber: String) -> Bool {
        guard let floor = AppConfiguration.Rooms.extractFloor(from: roomNumber) else {
            return false
        }
        return isFloorActive(floor)
    }
    
    /// Возвращает количество активных этажей
    var activeFloorsCount: Int {
        return activeFloors.count
    }
    
    /// Возвращает список активных этажей отсортированный
    var sortedActiveFloors: [Int] {
        return Array(activeFloors).sorted()
    }
    
    /// Возвращает список неактивных этажей
    var inactiveFloors: [Int] {
        let allFloors = Set(AppConfiguration.Rooms.allFloors)
        return Array(allFloors.subtracting(activeFloors)).sorted()
    }
}

/// Расширение для Room с поддержкой этажей
extension Room {
    /// Возвращает этаж комнаты
    var floor: Int? {
        return AppConfiguration.Rooms.extractFloor(from: number)
    }
    
    /// Проверяет, находится ли комната на активном этаже
    var isOnActiveFloor: Bool {
        guard let floor = self.floor else { return false }
        return FloorManager.shared.isFloorActive(floor)
    }
} 