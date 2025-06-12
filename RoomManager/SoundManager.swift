import Foundation
import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()

    enum SoundType: String, CaseIterable {
        case addRoom
        case lockUnlock
        case toggleStatus
    }

    struct SoundOption: Identifiable {
        let id: SystemSoundID
        let nameKey: String
    }

    private let soundOptions: [SoundOption] = [
        SoundOption(id: 1000, nameKey: "soundNewMail"),
        SoundOption(id: 1001, nameKey: "soundMailSent"),
        SoundOption(id: 1002, nameKey: "soundVoicemail"),
        SoundOption(id: 1022, nameKey: "soundChime"),
        SoundOption(id: 1057, nameKey: "soundBell"),
        SoundOption(id: 1103, nameKey: "soundLock"),
        SoundOption(id: 1156, nameKey: "soundTock"),
        SoundOption(id: 1306, nameKey: "soundTweet")
    ]

    private var soundSettings: [String: SystemSoundID] = [:]
    private var viewModel: RoomViewModel?

    init() {
        loadSoundSettings()
    }

    func setViewModel(_ vm: RoomViewModel) {
        viewModel = vm
    }

    func playSound(for type: SoundType) {
        if let soundID = soundSettings[type.rawValue] {
            AudioServicesPlaySystemSound(soundID)
        }
    }
    
    // Максимальная тактильная отдача для важных действий (например, длинный тап для меню)
    func provideMaximumHapticFeedback() {
        // Используем комбинацию различных типов отдачи для максимального эффекта
        
        // 1. Сначала самый сильный удар
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        heavyGenerator.prepare()
        heavyGenerator.impactOccurred(intensity: 1.0) // Максимальная интенсивность
        
        // 2. Затем добавляем feedback с успехом для усиления
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.prepare()
        
        // Небольшая задержка для комбинированного эффекта
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            notificationGenerator.notificationOccurred(.success)
        }
        
        // 3. Дополнительный удар для продления ощущения
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let extraGenerator = UIImpactFeedbackGenerator(style: .heavy)
            extraGenerator.prepare()
            extraGenerator.impactOccurred(intensity: 0.8)
        }
    }

    func setSound(_ soundID: SystemSoundID, for type: SoundType) {
        soundSettings[type.rawValue] = soundID
        saveSoundSettings()
    }

    func getSoundID(for type: SoundType) -> SystemSoundID? {
        soundSettings[type.rawValue]
    }

    func getSoundName(for soundID: SystemSoundID) -> String {
        if let soundOption = soundOptions.first(where: { $0.id == soundID }) {
            return viewModel?.getTranslation(for: soundOption.nameKey) ?? soundOption.nameKey
        }
        return "Sound \(soundID)"
    }

    func getAllSoundOptions() -> [SoundOption] {
        soundOptions
    }

    private func saveSoundSettings() {
        let settings = soundSettings.mapValues { NSNumber(value: $0) }
        UserDefaults.standard.set(settings, forKey: "soundSettings")
    }

    private func loadSoundSettings() {
        if let saved = UserDefaults.standard.dictionary(forKey: "soundSettings") as? [String: NSNumber] {
            soundSettings = saved.mapValues { $0.uint32Value }
        } else {
            soundSettings[SoundType.addRoom.rawValue] = 1156
            soundSettings[SoundType.lockUnlock.rawValue] = 1103
            soundSettings[SoundType.toggleStatus.rawValue] = 1104
        }
    }
}
