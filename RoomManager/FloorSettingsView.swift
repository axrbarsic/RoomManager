import SwiftUI

struct FloorSettingsView: View {
    @ObservedObject var viewModel: RoomViewModel
    @ObservedObject var floorManager = FloorManager.shared
    @Environment(\.presentationMode) var presentationMode
    let isLocked: Bool
    
    var body: some View {
        NavigationView {
            List {
                // Информационная секция
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.getTranslation(for: "floorSettingsDescription"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(viewModel.getTranslation(for: "floorSettingsInfo"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Быстрые действия
                Section(header: Text(viewModel.getTranslation(for: "quickActions"))) {
                    Button(action: {
                        if !isLocked {
                            withAnimation {
                                floorManager.enableAllFloors()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(viewModel.getTranslation(for: "enableAllFloors"))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .disabled(isLocked)
                    
                    Button(action: {
                        if !isLocked {
                            withAnimation {
                                floorManager.disableAllFloors()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text(viewModel.getTranslation(for: "disableAllFloors"))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .disabled(isLocked)
                }
                
                // Индивидуальные этажи
                Section(header: Text(viewModel.getTranslation(for: "individualFloors"))) {
                    ForEach(AppConfiguration.Rooms.allFloors, id: \.self) { floor in
                        HStack {
                            // Иконка этажа
                            ZStack {
                                Circle()
                                    .fill(floorManager.isFloorActive(floor) ? Color.green : Color.red)
                                    .frame(width: 30, height: 30)
                                
                                Text("\(floor)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: viewModel.getTranslation(for: "floorNumber"), floor))
                                    .font(.headline)
                                
                                Text(floorStatus(for: floor))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Переключатель
                            Toggle("", isOn: Binding(
                                get: { floorManager.isFloorActive(floor) },
                                set: { _ in
                                    if !isLocked {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            floorManager.toggleFloor(floor)
                                        }
                                    }
                                }
                            ))
                            .disabled(isLocked)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isLocked {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    floorManager.toggleFloor(floor)
                                }
                            }
                        }
                    }
                }
                
                // Статистика
                Section(header: Text(viewModel.getTranslation(for: "statistics"))) {
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.blue)
                        Text(viewModel.getTranslation(for: "activeFloors"))
                        Spacer()
                        Text("\(floorManager.activeFloorsCount)/\(AppConfiguration.Rooms.allFloors.count)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Image(systemName: "building")
                            .foregroundColor(.orange)
                        Text(viewModel.getTranslation(for: "visibleRooms"))
                        Spacer()
                        Text("\(visibleRoomsCount)")
                            .fontWeight(.semibold)
                    }
                    
                    if !floorManager.inactiveFloors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "eye.slash")
                                    .foregroundColor(.red)
                                Text(viewModel.getTranslation(for: "hiddenFloors"))
                                Spacer()
                            }
                            
                            Text(floorManager.inactiveFloors.map { "\($0)" }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.getTranslation(for: "floorSettings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.getTranslation(for: "done")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func floorStatus(for floor: Int) -> String {
        let roomsOnFloor = viewModel.rooms.filter { room in
            AppConfiguration.Rooms.extractFloor(from: room.number) == floor
        }.count
        
        if floorManager.isFloorActive(floor) {
            return String(format: viewModel.getTranslation(for: "floorActiveWithRooms"), roomsOnFloor)
        } else {
            return String(format: viewModel.getTranslation(for: "floorInactiveWithRooms"), roomsOnFloor)
        }
    }
    
    private var visibleRoomsCount: Int {
        return viewModel.filteredRoomsByFloor.count
    }
}

// Превью для SwiftUI
struct FloorSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FloorSettingsView(
            viewModel: RoomViewModel(),
            isLocked: false
        )
    }
} 