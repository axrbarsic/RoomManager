import SwiftUI

struct CrazySettingsView: View {
    @ObservedObject var effectManager = RandomEffectManager.shared
    @ObservedObject var viewModel: RoomViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Toggle(isOn: $effectManager.isCrazyModeActive) {
                Text(effectManager.isCrazyModeActive ? viewModel.getTranslation(for: "crazyModeOn") : viewModel.getTranslation(for: "crazyModeOff"))
            }
            .padding()
            .toggleStyle(SwitchToggleStyle(tint: .red))
            
            if effectManager.isCrazyModeActive {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.getTranslation(for: "effectIntensity"))
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "tortoise")
                            .foregroundColor(.gray)
                        
                        Slider(
                            value: $effectManager.intensity,
                            in: 0.5...2.0,
                            step: 0.1
                        )
                        
                        Image(systemName: "hare")
                            .foregroundColor(.gray)
                    }
                    
                    Text(String(format: viewModel.getTranslation(for: "currentSpeed"), effectManager.intensity))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal)
            }
        }
    }
}

struct CrazySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CrazySettingsView(viewModel: RoomViewModel())
    }
} 