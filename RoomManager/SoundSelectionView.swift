import SwiftUI
import AVFoundation

struct SoundSelectionView: View {
    let soundType: SoundManager.SoundType
    @ObservedObject var viewModel: RoomViewModel
    @State private var selectedSoundID: SystemSoundID?

    var body: some View {
        List {
            ForEach(SoundManager.shared.getAllSoundOptions()) { soundOption in
                HStack {
                    Text(SoundManager.shared.getSoundName(for: soundOption.id))
                    Spacer()
                    if soundOption.id == selectedSoundID {
                        Image(systemName: "checkmark")
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSoundID = soundOption.id
                    SoundManager.shared.setSound(soundOption.id, for: soundType)
                    AudioServicesPlaySystemSound(soundOption.id)
                }
            }
        }
        .onAppear {
            selectedSoundID = SoundManager.shared.getSoundID(for: soundType)
            SoundManager.shared.setViewModel(viewModel)
        }
        .navigationTitle(getSoundTypeTitle())
    }
    
    private func getSoundTypeTitle() -> String {
        switch soundType {
        case .addRoom:
            return viewModel.getTranslation(for: "soundTypeAddRoom")
        case .lockUnlock:
            return viewModel.getTranslation(for: "soundTypeLockUnlock")
        case .toggleStatus:
            return viewModel.getTranslation(for: "soundTypeToggleStatus")
        }
    }
}
