import Foundation
import SwiftUI

/// Центральная конфигурация приложения
struct AppConfiguration {
    
    // MARK: - UI Constants
    struct UI {
        static let globalHorizontalPadding: CGFloat = 10
        static let bannerHorizontalPadding: CGFloat = 10
        static let cellCornerRadius: CGFloat = 8
        static let animationDuration: Double = 0.25
        static let gridSpacing: CGFloat = 0
        static let safetyMargin: CGFloat = 5.0
        
        // Размеры ячеек
        static let cellHeight: CGFloat = 70
        static let cellMinWidth: CGFloat = 60
        
        // Toast уведомления
        static let toastDuration: TimeInterval = 2.0
        static let toastAnimationDuration: Double = 0.3
    }
    
    // MARK: - Performance Constants
    struct Performance {
        static let maxHistorySize: Int = 100
        static let backgroundTaskExpiration: TimeInterval = 15.0
        static let keyboardTimerInterval: TimeInterval = 15.0
        static let displayLinkUpdateInterval: TimeInterval = 0.05
        
        // Metal/GPU настройки
        static let metalRefreshRateMin: Double = 30
        static let metalRefreshRateMax: Double = 120
        static let metalRefreshRateDefault: Double = 120
        
        // Эффекты пометки - оптимизировано для 120fps
        static let markEffectDuration: TimeInterval = 0.6
        static let maxConcurrentEffects: Int = 25 // Увеличили лимит для большого количества комнат
        static let effectTransitionDuration: TimeInterval = 1.0/120.0 // 120fps анимации
        
        // Настройки кэширования для оптимизации
        static let transformCacheSize: Int = 50 // Максимум кэшированных преобразований
        static let cacheUpdateFrequency: Double = 120.0 // Обновлений в секунду
    }
    
    // MARK: - Room Constants
    struct Rooms {
        static let validRoomRange = 1...30
        static let floorRange = 1...5
        static let excludedRoomNumber = 29
        static let defaultRoomColor: Room.RoomColor = .none
        
        // Форматирование номеров комнат
        static let numberFormat = "%02d"
        static func formatRoomNumber(floor: Int, room: Int) -> String {
            return "\(floor)\(String(format: numberFormat, room))"
        }
        
        // Извлечение этажа из номера комнаты
        static func extractFloor(from roomNumber: String) -> Int? {
            guard roomNumber.count >= 3 else { return nil }
            let floorString = String(roomNumber.prefix(1))
            return Int(floorString)
        }
        
        // Все доступные этажи
        static let allFloors = Array(floorRange)
    }
    
    // MARK: - Audio Constants
    struct Audio {
        static let defaultVolume: Float = 0.5
        static let feedbackIntensity: UIImpactFeedbackGenerator.FeedbackStyle = .medium
        static let maximumFeedbackIntensity: UIImpactFeedbackGenerator.FeedbackStyle = .heavy
        static let menuLongPressMinDuration: Double = 0.5
    }
    
    // MARK: - Time Constants
    struct Time {
        static let timePickerMinutes = [0, 15, 30, 45]
        static let timePickerHours = Array(1...12)
        static let defaultTimePickerHour = 12
        static let defaultTimePickerMinute = 0
    }
    
    // MARK: - File System
    struct FileSystem {
        static let historyFileName = "action_history.json"
        static let backupFolderName = "auto_backups"
        static let roomsFileName = "rooms.json"
        static let backupsFileName = "backups.json"
        static let tempVideoFileName = "temp_background.mp4"
        
        // Backup extensions
        static let backupExtension = "backup"
        static let tempExtension = "tmp"
    }
    
    // MARK: - Network/Video
    struct Media {
        static let videoCompressionQuality: Float = 0.8
        static let maxVideoSize: Int = 50 * 1024 * 1024 // 50MB
        static let supportedImageFormats = ["jpg", "jpeg", "png", "heic"]
        static let supportedVideoFormats = ["mp4", "mov", "m4v"]
    }
    
    // MARK: - Validation
    struct Validation {
        static let roomNumberPattern = "^[1-5]\\d{2}$"
        static let maxRoomNumberLength = 3
        static let minRoomNumberLength = 3
    }
    
    // MARK: - Colors
    struct Colors {
        static let primaryBackgroundColor = Color.black
        static let secondaryBackgroundColor = Color.gray.opacity(0.1)
        static let accentColor = Color.blue
        static let successColor = Color.green
        static let errorColor = Color.red
        static let warningColor = Color.orange
        
        // Room status colors
        static func roomStatusColor(for status: Room.RoomColor) -> Color {
            switch status {
            case .none: return Color.yellow.opacity(0.85)
            case .red: return Color.red
            case .green: return Color.green
            case .purple: return Color.purple
            case .blue: return Color.blue
            case .white: return Color.white
            }
        }
        
        static func roomTextColor(for status: Room.RoomColor) -> Color {
            switch status {
            case .none, .green, .white: return .black
            case .red, .purple, .blue: return .white
            }
        }
    }
    
    // MARK: - Debug Configuration
    struct Debug {
        #if DEBUG
        static let isDebugMode = true
        static let showDebugInfo = true
        #else
        static let isDebugMode = false
        static let showDebugInfo = false
        #endif
        
        static let enableVerboseLogging = isDebugMode
        static let enablePerformanceMonitoring = isDebugMode
    }
    
    // MARK: - Feature Flags
    struct Features {
        static let enableMetalEffects = true
        static let enablePhysicsEffects = true
        static let enableVideoBackgrounds = true
        static let enableAdvancedStatistics = true
        static let enableActionHistory = true
    }
} 