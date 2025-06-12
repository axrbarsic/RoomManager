import SwiftUI

struct RoomListView: View {
    @ObservedObject var viewModel: RoomViewModel
    let isLocked: Bool
    @Environment(\.presentationMode) private var presentationMode
    @State private var showCopySuccessAlert = false
    @State private var sortOption: SortOption = .number
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    private enum SortOption: String, CaseIterable {
        case number
        case redTime
        case greenTime
    }

    private func roomRow(_ room: Room) -> some View {
        HStack {
            Text(room.number)
                .frame(width: UIScreen.main.bounds.width * 0.2)
                .foregroundColor(colorForRoom(room))
            
            timeColumn(room.redTimestamp, color: .red)
            timeColumn(room.greenTimestamp, color: .green)
        }
        .padding(.vertical, 5)
        .background(Color(.systemBackground))
    }
    
    private func timeColumn(_ timestamp: Date?, color: Color) -> some View {
        Group {
            if let time = timestamp {
                Text(formattedTime(time))
                    .foregroundColor(color)
            } else {
                Text("-")
                    .foregroundColor(.gray)
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.3)
    }
    
    private func colorForRoom(_ room: Room) -> Color {
        switch room.color {
        case .green: return .green
        case .red: return .red
        case .purple: return .purple
        case .none: return .yellow
        case .blue: return .blue
        case .white: return .white
        }
    }
    
    private func headerRow() -> some View {
        HStack {
            Text(viewModel.getTranslation(for: "number"))
                .frame(width: UIScreen.main.bounds.width * 0.2)
            Text(viewModel.getTranslation(for: "redTime"))
                .frame(width: UIScreen.main.bounds.width * 0.3)
            Text(viewModel.getTranslation(for: "greenTime"))
                .frame(width: UIScreen.main.bounds.width * 0.3)
        }
        .foregroundColor(.gray)
        .font(.caption)
        .padding(.horizontal)
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker(viewModel.getTranslation(for: "sortBy"), selection: $sortOption) {
                    Text(viewModel.getTranslation(for: "sortOptionNumber")).tag(SortOption.number)
                    Text(viewModel.getTranslation(for: "sortOptionRedTime")).tag(SortOption.redTime)
                    Text(viewModel.getTranslation(for: "sortOptionGreenTime")).tag(SortOption.greenTime)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                headerRow()

                TabView {
                    // Список комнат
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(sortedRooms()) { room in
                                roomRow(room)
                            }
                        }
                        .padding(.horizontal, 5)
                    }
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text(viewModel.getTranslation(for: "list"))
                    }

                    // Статистика
                    StatisticsView(viewModel: viewModel)
                        .tabItem {
                            Image(systemName: "chart.xyaxis.line")
                            Text(viewModel.getTranslation(for: "statistics"))
                        }
                }
            }
            .navigationBarTitle(viewModel.getTranslation(for: "currentRooms"), displayMode: .inline)
            .navigationBarItems(trailing: cancelButton)
            .alert(viewModel.getTranslation(for: "copySuccess"), isPresented: $showCopySuccessAlert) {
                Button("OK", role: .cancel) { }
            }
            .onChange(of: selectedDate) { newValue in
                loadRooms(for: newValue)
            }
            .sheet(isPresented: $showDatePicker) {
                CalendarView(selectedDate: $selectedDate, viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sortedRooms() -> [Room] {
        // Показываем зеленые и голубые комнаты, исключая отмеченные как "сделано до 9:30"
        let rooms = viewModel.filteredRoomsByFloor.filter { ($0.color == .green || $0.color == .blue) && !$0.isCompletedBefore930 }
        
        switch sortOption {
        case .number:
            return rooms.sorted { $0.number < $1.number }
        case .redTime:
            return rooms.sorted { room1, room2 in
                guard let time1 = room1.redTimestamp else { return false }
                guard let time2 = room2.redTimestamp else { return true }
                return time1 > time2
            }
        case .greenTime:
            return rooms.sorted { room1, room2 in
                guard let time1 = room1.greenTimestamp else { return false }
                guard let time2 = room2.greenTimestamp else { return true }
                return time1 > time2
            }
        }
    }

    private func buildFloorStatistics(floor: Int) -> some View {
                    let floorRooms = viewModel.filteredRoomsByFloor.filter { Int($0.number.prefix(1)) == floor }
        let completedRooms = floorRooms.filter { $0.color == .green || $0.color == .blue }
        let percentage = floorRooms.isEmpty ? 0 : Double(completedRooms.count) / Double(floorRooms.count) * 100

        return HStack {
            Text(String(format: viewModel.getTranslation(for: "floor"), floor))
                .font(.headline)
            
            Spacer()
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(percentage) / 100)
                }
            }
            .frame(height: 20)
            .cornerRadius(5)
            
            Text(String(format: "%.0f%%", percentage))
                .frame(width: 50)
        }
        .frame(height: 30)
    }

    private var cancelButton: some View {
        Button(viewModel.getTranslation(for: "cancel")) {
            presentationMode.wrappedValue.dismiss()
        }
    }

    private func loadRooms(for date: Date) {
        let _ = Calendar.current.startOfDay(for: date)
        // Новая структура HistoryRecord не содержит массив комнат
        // Эта функция больше не актуальна, так как история теперь хранит отдельные действия
        // Оставляем пустую реализацию или удаляем вызов
    }

    private func copyGreenRoomsToClipboard() {
        let greenRooms = viewModel.filteredRoomsByFloor.filter { $0.color == .green && $0.greenTimestamp != nil }
        var clipboardText = ""
        for room in greenRooms {
            if let greenTime = room.greenTimestamp {
                clipboardText += "\(room.number) \(formattedTime(greenTime)) \(viewModel.getTranslation(for: "ready"))\n"
            }
        }
        UIPasteboard.general.string = clipboardText
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func floorColor(for number: String) -> Color {
        guard let floorDigit = Int(number.prefix(1)) else {
            return Color.gray
        }
        switch floorDigit {
        case 1: return Color.blue.opacity(0.8)
        case 2: return Color.cyan
        case 3: return Color.orange
        case 4: return Color.pink
        case 5: return Color.yellow
        default: return Color.gray
        }
    }

    private func getLegendName(for color: Color) -> String {
        viewModel.getLegendName(for: color)
    }
}
