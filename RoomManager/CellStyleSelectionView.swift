import SwiftUI

struct CellStyleSelectionView: View {
    @ObservedObject var viewModel: RoomViewModel
    let isLocked: Bool
    @AppStorage("cellStyle") private var cellStyle: Int = 1
    @Environment(\.presentationMode) private var presentationMode
    
    // Демо-данные для примеров ячеек
    private let demoRooms: [Room] = [
        {
            var room = Room(number: "101")
            room.color = .none
            room.isMarked = false
            return room
        }(),
        {
            var room = Room(number: "202")
            room.color = .red
            room.isMarked = true
            return room
        }(),
        {
            var room = Room(number: "303")
            room.color = .green
            room.isMarked = false
            return room
        }(),
        {
            var room = Room(number: "404")
            room.color = .blue
            room.isMarked = false
            return room
        }()
    ]
    
    var body: some View {
        List {
            Section {
                Text(viewModel.getTranslation(for: "cellStyleDescription"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
            
            // Плоский стиль
            styleSection(title: "flatStyle", style: 0)
            
            // Классический 3D стиль
            styleSection(title: "classicStyle", style: 1)
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(viewModel.getTranslation(for: "cellStyleTitle"))
    }
    
    private func styleSection(title: String, style: Int) -> some View {
        Section {
            Button(action: {
                if !isLocked {
                    withAnimation {
                        cellStyle = style
                    }
                }
            }) {
                HStack {
                    Text(viewModel.getTranslation(for: title))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if cellStyle == style {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .disabled(isLocked)
            
            // Пример ячеек с выбранным стилем
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(demoRooms) { room in
                        createDemoRoomCell(room: room, style: style)
                            .frame(width: 100, height: 70)
                    }
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, -20)
        }
    }
    
    // Создаем демонстрационную ячейку комнаты
    private func createDemoRoomCell(room: Room, style: Int) -> some View {
        let content = VStack(spacing: 5) {
            Text(room.number)
                .font(.title2)
                .bold()
                .foregroundColor(room.color == .white ? .black : .black)
            
            if room.color == .purple, let time = room.availableTime {
                Text(time)
                    .font(.caption)
                    .foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        // Применяем выбранный стиль к демо-ячейке
        switch style {
        case 0: // Плоский
            return AnyView(
                content
                    .background(
                        Group {
                            if room.color == .white {
                                Color.white
                            } else {
                                cellColor(for: room.color)
                            }
                        }
                    )
                    .cornerRadius(8)
                    .overlay(
                        room.isMarked && room.color != .white ? createDemoTriangle() : nil
                    )
            )
            
        case 1: // Классический 3D
            return AnyView(
                content
                    .background(
                        Group {
                            if room.color == .white {
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white, Color.white.opacity(0.85)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            } else {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        cellColorWithBrightness(for: room.color, amount: 1.2),
                                        cellColor(for: room.color),
                                        cellColorWithBrightness(for: room.color, amount: 0.8)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                        }
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.black.opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .opacity(0.7)
                    )
                    .shadow(
                        color: Color.black.opacity(0.25),
                        radius: 5,
                        x: 2,
                        y: 2
                    )
                    .rotation3DEffect(
                        .degrees(3),
                        axis: (x: 0.5, y: 0, z: 0)
                    )
                    .overlay(
                        room.isMarked && room.color != .white ? createDemoTriangle() : nil
                    )
            )
            
        default:
            return AnyView(content.background(Color.gray).cornerRadius(8))
        }
    }
    
    // Создаем круг для пометок (вместо треугольника)
    private func createDemoTriangle() -> some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.green) // Используем зеленый как демонстрационный инверсный цвет
                .frame(width: 20, height: 20)
                .padding(5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    // Возвращает цвет ячейки в зависимости от статуса
    private func cellColor(for roomColor: Room.RoomColor) -> Color {
        switch roomColor {
        case .none:
            return Color.yellow.opacity(0.85)
        case .red:
            return Color.red
        case .green:
            return Color.green
        case .purple:
            return Color.purple
        case .blue:
            return Color.blue
        case .white:
            return Color.clear
        }
    }
    
    // Меняет яркость цвета
    private func cellColorWithBrightness(for roomColor: Room.RoomColor, amount: CGFloat) -> Color {
        let originalColor = cellColor(for: roomColor)
        
        let uiColor = UIColor(originalColor)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        
        if uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            let newBrightness = min(max(b * amount, 0), 1)
            return Color(UIColor(hue: h, saturation: s, brightness: newBrightness, alpha: a))
        }
        
        return originalColor
    }
} 