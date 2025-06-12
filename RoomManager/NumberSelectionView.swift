import SwiftUI
import AVFoundation
import Foundation

struct NumberSelectionView: View {
    @ObservedObject var viewModel: RoomViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isVerticalLayout = true
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 5)
    
    // Вычисляемое свойство для упорядоченного списка номеров комнат
    private var orderedRoomNumbers: [String] {
        var numbers: [String] = []
        
        if isVerticalLayout {
            for number in AppConfiguration.Rooms.validRoomRange where number != AppConfiguration.Rooms.excludedRoomNumber {
                for floor in AppConfiguration.Rooms.floorRange {
                    numbers.append(AppConfiguration.Rooms.formatRoomNumber(floor: floor, room: number))
                }
            }
        } else {
            for floor in AppConfiguration.Rooms.floorRange {
                for number in AppConfiguration.Rooms.validRoomRange where number != AppConfiguration.Rooms.excludedRoomNumber {
                    numbers.append(AppConfiguration.Rooms.formatRoomNumber(floor: floor, room: number))
                }
            }
        }
        return numbers
    }

    var body: some View {
        VStack(spacing: 0) {
            // Компактное верхнее меню в один ряд
            HStack {
                Button(action: {
                    withAnimation {
                        isVerticalLayout.toggle()
                    }
                }) {
                    Image(systemName: isVerticalLayout ? "arrow.left.and.right" : "arrow.up.and.down")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(viewModel.getTranslation(for: "selectRooms"))
                    .font(.headline)
                
                Spacer()
                
                Button(viewModel.getTranslation(for: "done")) {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .frame(height: 44)
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 0) {
                    // Используем новый единый ForEach
                    ForEach(orderedRoomNumbers, id: \.self) { roomNumber in
                        NumberBallView(
                            number: roomNumber,
                            isSelected: viewModel.rooms.contains(where: { $0.number == roomNumber }),
                            onTap: {
                                toggleRoomSelection(roomNumber: roomNumber)
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxHeight: .infinity)
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private func toggleRoomSelection(roomNumber: String) {
        // Валидация номера комнаты
        let validation = RoomValidator.validateRoomNumber(roomNumber)
        guard validation.isValid else {
            // Можно показать ошибку пользователю
            return
        }
        
        if let index = viewModel.rooms.firstIndex(where: { $0.number == roomNumber }) {
            // Записываем действие удаления комнаты в историю перед удалением
            ActionHistoryManager.shared.recordDeleteRoom(
                roomNumber: roomNumber, 
                prevColor: viewModel.rooms[index].color, 
                rooms: viewModel.rooms
            )
            
            viewModel.rooms.remove(at: index)
            viewModel.saveRooms()
        } else {
            // Дополнительная валидация для новой комнаты
            let newRoomValidation = RoomValidator.validateNewRoom(roomNumber: roomNumber, existingRooms: viewModel.rooms)
            guard newRoomValidation.isValid else {
                return
            }
            
            _ = viewModel.addRoom(number: roomNumber)
            
            // Записываем действие добавления комнаты в историю после добавления
            if viewModel.rooms.contains(where: { $0.number == roomNumber }) {
                ActionHistoryManager.shared.recordAddRoom(
                    roomNumber: roomNumber,
                    rooms: viewModel.rooms
                )
            }
        }
        
        // Используем конфигурацию для haptic feedback
        let generator = UIImpactFeedbackGenerator(style: AppConfiguration.Audio.feedbackIntensity)
        generator.prepare()
        generator.impactOccurred()
        
        SoundManager.shared.playSound(for: .toggleStatus)
    }
}

struct NumberBallView: View {
    let number: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        } label: {
            Text(number)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isSelected ? .white : .black)
                .frame(width: UIScreen.main.bounds.width / 5, height: 60)
                .background(
                    Rectangle()
                        .fill(isSelected ? Color.blue : Color(red: 255/255, green: 240/255, blue: 240/255))
                )
                .overlay(
                    Rectangle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(NumberBallButtonStyle())
    }
}

struct NumberBallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
