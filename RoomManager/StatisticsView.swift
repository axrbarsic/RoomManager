import SwiftUI
// Удаляем полностью импорт Charts
// import Charts

// Удаляем проблемное расширение
// Вместо этого создаем обертку для этажа
struct FloorID: Identifiable {
    let id: Int
    init(_ floor: Int) { self.id = floor }
}

struct StatisticsView: View {
    @ObservedObject var viewModel: RoomViewModel
    @State private var selectedFloor: Int? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Диаграмма приоритета этажей
                    if !viewModel.floorStats.isEmpty {
                        priorityChartSection
                    }
                    
                    // Круговая диаграмма статусов
                    if !viewModel.statusDistribution.isEmpty {
                        statusDistributionSection
                    }
                    
                    // Легенда статусов
                    if !viewModel.statusDistribution.isEmpty {
                        statusLegend
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.getTranslation(for: "statistics"))
        }
        .preferredColorScheme(.dark)
    }
    
    private var priorityChartSection: some View {
        VStack(alignment: .leading) {
            Text(viewModel.getTranslation(for: "floorPriority"))
                .font(.headline)
                .padding(.horizontal)
            
            // Заменяем компонент Charts на свой собственный
            VStack(spacing: 8) {
                ForEach(viewModel.floorStats) { stat in
                    HStack {
                        // Метка этажа
                        Text("\(stat.floor)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 30)
                        
                        // Градиентная полоса приоритета
                        GeometryReader { geometry in
                            // Находим максимальный приоритет для масштабирования
                            let maxPriority = viewModel.floorStats.map { $0.priority }.max() ?? 1
                            let barWidth = CGFloat(stat.priority) / CGFloat(maxPriority) * geometry.size.width
                            
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width, height: 25)
                                
                                LinearGradient(
                                    gradient: Gradient(colors: [.red.opacity(0.6), .red]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: barWidth, height: 25)
                                
                                // Аннотация сверху
                                Text("\(stat.redRooms)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.leading, barWidth - 15)
                                    .padding(.top, -15)
                            }
                        }
                        .frame(height: 25)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(15)
            .gesture(
                DragGesture().onEnded { value in
                    handleChartTap(at: value.location)
                }
            )
        }
    }
    
    private var statusDistributionSection: some View {
        VStack(alignment: .leading) {
            Text(viewModel.getTranslation(for: "statusDistribution"))
                .font(.headline)
                .padding(.horizontal)
            
            // Заменяем Chart с SectorMark на собственную реализацию
            VStack {
                // Круговая диаграмма
                ZStack {
                    ForEach(viewModel.statusDistribution.indices, id: \.self) { index in
                        let data = viewModel.statusDistribution[index]
                        PieSliceView(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            color: data.color
                        )
                        
                        // Процентная метка для каждого сектора
                        let midAngle = startAngle(for: index) + (endAngle(for: index) - startAngle(for: index)) / 2
                        let labelDistance: CGFloat = 70 // Расстояние метки от центра
                        let labelX = cos(midAngle.radians) * labelDistance
                        let labelY = sin(midAngle.radians) * labelDistance
                        
                        Text("\(Int(round(data.percentage * 100)))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .position(x: 125 + labelX, y: 125 + labelY)
                    }
                    
                    // Центральное отверстие для donut-диаграммы
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 100, height: 100)
                }
                .frame(width: 250, height: 250)
            }
            .frame(height: 250)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(15)
        }
    }
    
    // Вспомогательные функции для расчёта углов для круговой диаграммы
    private func startAngle(for index: Int) -> Angle {
        if index == 0 {
            return .degrees(0)
        }
        
        // Суммируем все предыдущие проценты
        let previousTotal = viewModel.statusDistribution[..<index]
            .reduce(0) { $0 + $1.percentage }
        
        return .degrees(previousTotal * 360)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let total = viewModel.statusDistribution[...index]
            .reduce(0) { $0 + $1.percentage }
        
        return .degrees(total * 360)
    }
    
    private var statusLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(viewModel.statusDistribution, id: \.color) { data in
                HStack {
                    Circle()
                        .fill(data.color)
                        .frame(width: 20, height: 20)
                    
                    Text("\(viewModel.getTranslation(for: data.color == .green ? "green" : data.color == .red ? "red" : "blue")): \(data.count)")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(round(data.percentage * 100)))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func handleChartTap(at location: CGPoint) {
        let chartWidth = UIScreen.main.bounds.width - 40
        let barWidth = chartWidth / CGFloat(viewModel.floorStats.count)
        let floorIndex = Int(location.x / barWidth)
        
        guard floorIndex >= 0 && floorIndex < viewModel.floorStats.count else { return }
        selectedFloor = viewModel.floorStats[floorIndex].floor
    }
}

// Новое представление для детальной информации по этажу
struct FloorDetailView: View {
    let floor: Int
    let viewModel: RoomViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Круговой прогресс
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 20)
                            .frame(width: 200, height: 200)
                        
                        Circle()
                            .trim(from: 0, to: getCompletionRate(for: floor))
                            .stroke(
                                getBarColor(for: floor),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text(String(format: "%.0f%%", getCompletionRate(for: floor) * 100))
                                .font(.system(size: 40, weight: .bold))
                            Text(viewModel.getTranslation(for: "completionRate"))
                                .font(.caption)
                        }
                    }
                    .padding()
                    
                    // Детальная статистика
                    VStack(spacing: 15) {
                        StatCard(
                            title: viewModel.getTranslation(for: "priority"),
                            value: String(format: "%.0f%%", getPriority(for: floor) * 100),
                            unit: viewModel.getTranslation(for: "priority"),
                            color: .blue
                        )
                        
                        StatCard(
                            title: viewModel.getTranslation(for: "totalRooms"),
                            value: "\(getTotalRooms(for: floor))",
                            unit: viewModel.getTranslation(for: "rooms"),
                            color: .blue
                        )
                        
                        StatCard(
                            title: viewModel.getTranslation(for: "completedRooms"),
                            value: "\(getCompletedRooms(for: floor))",
                            unit: viewModel.getTranslation(for: "rooms"),
                            color: .green
                        )
                    }
                    .padding()
                }
            }
            .navigationBarTitle(
                String(format: viewModel.getTranslation(for: "floorDetailsTitle"), floor),
                displayMode: .inline
            )
            .navigationBarItems(trailing: Button(viewModel.getTranslation(for: "close")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func getCompletionRate(for floor: Int) -> Double {
        let rooms = viewModel.filteredRoomsByFloor.filter { Int($0.number.prefix(1)) == floor && !$0.isCompletedBefore930 }
        let completedRooms = rooms.filter { $0.color == .green || $0.color == .blue }
        return rooms.isEmpty ? 0.0 : Double(completedRooms.count) / Double(rooms.count)
    }
    
    private func getPriority(for floor: Int) -> Double {
        let rooms = viewModel.filteredRoomsByFloor.filter { Int($0.number.prefix(1)) == floor && !$0.isCompletedBefore930 }
        return rooms.isEmpty ? 0.0 : Double(rooms.filter { $0.color == .red }.count) / Double(rooms.count)
    }
    
    private func getTotalRooms(for floor: Int) -> Int {
        viewModel.filteredRoomsByFloor.filter { Int($0.number.prefix(1)) == floor && !$0.isCompletedBefore930 }.count
    }
    
    private func getCompletedRooms(for floor: Int) -> Int {
        viewModel.filteredRoomsByFloor.filter { Int($0.number.prefix(1)) == floor && !$0.isCompletedBefore930 && ($0.color == .green || $0.color == .blue) }.count
    }
    
    private func getBarColor(for floor: Int) -> Color {
        let priority = getPriority(for: floor)
        if priority > 0.5 {
            return .red
        } else if priority > 0.3 {
            return .orange
        } else if priority > 0.1 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(alignment: .bottom) {
                    Text(value)
                        .font(.title)
                        .bold()
                    Text(unit)
                        .font(.caption)
                        .padding(.bottom, 4)
                }
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

// Добавляем переводы в Translations.swift
/*
.ru: [
    ...
    "floorPriority": "Приоритет этажей",
    "statusDistribution": "Распределение статусов",
    "priority": "Приоритет",
    "status": "Статус",
    "green": "Зеленые",
    "red": "Красные",
    "blue": "Синие"
],
.en: [
    ...
    "floorPriority": "Floor Priority",
    "statusDistribution": "Status Distribution",
    "priority": "Priority",
    "status": "Status",
    "green": "Green",
    "red": "Red",
    "blue": "Blue"
]
*/

// Ниже добавляем структуру для создания сектора круговой диаграммы
struct PieSliceView: View {
    var startAngle: Angle
    var endAngle: Angle
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Внешний сектор
                Path { path in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    
                    path.move(to: center)
                    path.addArc(
                        center: center, 
                        radius: radius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .fill(color)
                
                // Внутренний круг для создания эффекта пончика
                Circle()
                    .fill(Color(UIColor.systemBackground))
                    .frame(width: min(geometry.size.width, geometry.size.height) * 0.6)
            }
        }
    }
} 