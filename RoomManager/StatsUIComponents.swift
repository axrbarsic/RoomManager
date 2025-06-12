import SwiftUI

// MARK: - Компактный компонент статистики для главного экрана
struct StatisticsCompactView: View {
    @ObservedObject var viewModel: RoomViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 20 // Отступы
            
            VStack(spacing: 15) {
                // Распределение статусов
                VStack(alignment: .leading, spacing: 8) {
                    // Центрируем баннер с помощью HStack
                    HStack {
                        Spacer()
                        StatusBannerView(viewModel: viewModel, availableWidth: availableWidth)
                        Spacer()
                    }
                    .frame(height: 70)
                }
                .padding(.bottom, 20)
                .background(Color.black.opacity(0.01))
                
                // Компактный график приоритета этажей
                VStack(spacing: 5) {
                    // Отображаем этажи в обратном порядке (снизу вверх: 1,2,3,4,5)
                    if viewModel.floorStats.isEmpty {
                        // Заполнитель для случая, когда нет данных по этажам
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: availableWidth, height: 140)
                            .cornerRadius(10)
                            .overlay(
                                Text(viewModel.getTranslation(for: "noData"))
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16, weight: .bold))
                            )
                    } else {
                        ForEach(viewModel.floorStats.sorted(by: { $0.floor > $1.floor })) { stat in
                            // Цветная полоска для этажа
                            ZStack {
                                // Фиксированный фон для стабильности размеров
                                Rectangle()
                                    .fill(Color.black.opacity(0.01))
                                    .frame(width: availableWidth, height: 22)
                                
                                // Метка этажа
                                HStack {
                                    Text("\(stat.floor)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 14)
                                    
                                    // Создаем горизонтальный стек для цветных сегментов
                                    HStack(spacing: 0) {
                                        // Получаем общее количество комнат на этаже
                                        let totalRooms = stat.totalRooms
                                        let segmentWidth = availableWidth - 20 // Вычитаем ширину метки этажа + отступ
                                        
                                        // Белые комнаты
                                        if stat.whiteRooms > 0 {
                                            let whiteWidth = max(15, segmentWidth * CGFloat(stat.whiteRooms) / CGFloat(totalRooms))
                                            Rectangle()
                                                .fill(Color.white)
                                                .frame(width: whiteWidth, height: 22)
                                                .overlay(
                                                    Group {
                                                        if whiteWidth > 25 {
                                                            Text("\(stat.whiteRooms)")
                                                                .foregroundColor(.black)
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                    }
                                                )
                                                .overlay(
                                                    Rectangle().stroke(Color.gray, lineWidth: 1)
                                                )
                                        }
                                        
                                        // Не заполненное пространство (желтые комнаты)
                                        let yellowRooms = totalRooms - stat.redRooms - stat.greenRooms - stat.blueRooms - stat.whiteRooms
                                        if yellowRooms > 0 {
                                            let yellowWidth = max(15, segmentWidth * CGFloat(yellowRooms) / CGFloat(totalRooms))
                                            Rectangle()
                                                .fill(Color(red: 1.0, green: 0.85, blue: 0.0)) // Яркий желтый
                                                .frame(width: yellowWidth, height: 22)
                                                .overlay(
                                                    Group {
                                                        if yellowWidth > 25 {
                                                            Text("\(yellowRooms)")
                                                                .foregroundColor(.black)
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                    }
                                                )
                                        }
                                        
                                        // Красные комнаты
                                        if stat.redRooms > 0 {
                                            let redWidth = max(15, segmentWidth * CGFloat(stat.redRooms) / CGFloat(totalRooms))
                                            Rectangle()
                                                .fill(Color(red: 1.0, green: 0.15, blue: 0.15)) // Яркий красный
                                                .frame(width: redWidth, height: 22)
                                                .overlay(
                                                    Group {
                                                        if redWidth > 25 {
                                                            Text("\(stat.redRooms)")
                                                                .foregroundColor(.black)
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                    }
                                                )
                                        }
                                        
                                        // Синие комнаты
                                        if stat.blueRooms > 0 {
                                            let blueWidth = max(15, segmentWidth * CGFloat(stat.blueRooms) / CGFloat(totalRooms))
                                            Rectangle()
                                                .fill(Color(red: 0.0, green: 0.45, blue: 1.0)) // Насыщенный синий
                                                .frame(width: blueWidth, height: 22)
                                                .overlay(
                                                    Group {
                                                        if blueWidth > 25 {
                                                            Text("\(stat.blueRooms)")
                                                                .foregroundColor(.black)
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                    }
                                                )
                                        }
                                        
                                        // Зеленые комнаты
                                        if stat.greenRooms > 0 {
                                            let greenWidth = max(15, segmentWidth * CGFloat(stat.greenRooms) / CGFloat(totalRooms))
                                            Rectangle()
                                                .fill(Color(red: 0.0, green: 0.95, blue: 0.2)) // Сочный зеленый
                                                .frame(width: greenWidth, height: 22)
                                                .overlay(
                                                    Group {
                                                        if greenWidth > 25 {
                                                            Text("\(stat.greenRooms)")
                                                                .foregroundColor(.black)
                                                                .font(.system(size: 10, weight: .bold))
                                                        }
                                                    }
                                                )
                                        }
                                    }
                                }
                            }
                            .frame(width: availableWidth, height: 22) // Уменьшенная высота
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal, 5)
                .frame(height: 140, alignment: .top) // Оптимизированная высота
                .background(Color.black.opacity(0.01))
                .padding(.bottom, 10) // Уменьшенный отступ снизу
            }
            .padding(.vertical, 5)
            .frame(width: geometry.size.width)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    private func getLegendName(for color: Color) -> String {
        viewModel.getLegendName(for: color)
    }
}

// MARK: - Компонент статистики для верхнего баннера
struct StatusBannerView: View {
    @ObservedObject var viewModel: RoomViewModel
    var availableWidth: CGFloat
    
    var body: some View {
        // Простой контейнер для баннера
        VStack(spacing: 0) {
            if viewModel.statusDistribution.filter({ $0.count > 0 }).isEmpty {
                // Заполнитель для случая, когда нет данных
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: availableWidth, height: 80)
                    .cornerRadius(10)
                    .overlay(
                        Text(viewModel.getTranslation(for: "noData"))
                            .foregroundColor(.gray)
                            .font(.system(size: 14, weight: .bold))
                    )
            } else {
                // Используем ZStack для простого наложения
                ZStack {
                    statusBanner(width: availableWidth)
                        .frame(width: availableWidth, height: 80)
                        .cornerRadius(10)
                }
            }
        }
        .frame(width: availableWidth, height: 80)
        .modifier(CenteredBannerModifier())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width > 0 { // Свайп вправо
                        // Запускаем тактильный отклик
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        
                        // Переключаем видимость белых комнат
                        withAnimation(.spring()) {
                            viewModel.toggleWhiteRoomsVisibility()
                        }
                    }
                }
        )
    }
    
    // Выносим создание баннера в отдельную функцию для улучшения производительности
    private func statusBanner(width: CGFloat) -> some View {
        // Используем подход как в полосках по этажам - ZStack с фиксированным фоном и HStack
        ZStack {
            // Базовый фон для стабильности размеров
            Rectangle()
                .fill(Color.black.opacity(0.01))
                .frame(width: width, height: 80)
            
            // HStack вместо ZStack с динамическими offset
            HStack(spacing: 0) {
                // Получаем отфильтрованные и отсортированные сегменты
                let segments = sortedSegments()
                
                // Используем единую величину общего количества комнат
                // Вычисляем общее количество комнат, как сумму всех сегментов (аналогично totalRooms в статистике по этажам)
                let totalCount = viewModel.statusDistribution.reduce(0) { $0 + $1.count }
                
                // Выводим только сегменты с положительным количеством
                ForEach(segments) { data in
                    // Вычисляем ширину сегмента пропорционально количеству, используя общее количество
                    let segmentWidth = max(20, width * CGFloat(data.count) / CGFloat(totalCount))
                    let percentage = Int(round(Double(data.count) / Double(totalCount) * 100))
                    
                    Rectangle()
                        .fill(data.color)
                        .frame(width: segmentWidth, height: 80)
                        .overlay(
                            Text("\(percentage)%")
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .bold))
                                .minimumScaleFactor(0.5)
                        )
                        .overlay(
                            data.color == .white ? 
                                Rectangle().stroke(Color.gray, lineWidth: 1) : nil
                        )
                }
            }
        }
    }
    
    // Кэшируем сортировку для оптимизации
    private func sortedSegments() -> [StatsUIStatusData] {
        // Обновляем порядок цветов с использованием новых ярких цветов
        let colorMap = [
            Color.white: Color.white,
            Color.yellow: Color(red: 1.0, green: 0.85, blue: 0.0), // Яркий желтый
            Color.red: Color(red: 1.0, green: 0.15, blue: 0.15), // Яркий красный
            Color.blue: Color(red: 0.0, green: 0.45, blue: 1.0), // Насыщенный синий
            Color.green: Color(red: 0.0, green: 0.95, blue: 0.2), // Сочный зеленый
        ]
        
        let order: [Color] = [.white, .yellow, .red, .blue, .green]
        
        // Создаем копию данных с обновленными цветами
        let updatedData = viewModel.statusDistribution
            .filter { $0.count > 0 }
            .map { data -> StatsUIStatusData in
                // Находим оригинальный цвет и заменяем его на яркий аналог
                if let brightColor = colorMap[data.color] {
                    return StatsUIStatusData(color: brightColor, count: data.count, total: data.total)
                }
                return data
            }
        
        return updatedData.sorted { 
            let index1 = order.firstIndex(of: $0.color) ?? 999
            let index2 = order.firstIndex(of: $1.color) ?? 999
            return index1 < index2
        }
    }
}

// MARK: - Расширение RoomViewModel для доступа к статистическим данным

extension RoomViewModel {
    // Возвращает статистику по этажам
    var floorStats: [StatsUIFloorStats] {
        // Рассчитываем статистику по этажам только для активных этажей
        let stats: [StatsUIFloorStats] = floorManager.sortedActiveFloors.compactMap { floor -> StatsUIFloorStats? in
            // Получаем все комнаты этажа, исключая белые если они скрыты
            let floorRooms = filteredRoomsByFloor.filter { room in
                let isOnFloor = Int(room.number.prefix(1)) == floor
                // Если белые комнаты скрыты, фильтруем их
                return isOnFloor && (!hideWhiteRooms || room.color != .white)
            }
            
            // Если нет комнат на этаже, пропускаем
            guard floorRooms.count > 0 else { return nil }
            
            return StatsUIFloorStats(
                floor: floor,
                redRooms: floorRooms.filter { $0.color == .red && !$0.isCompletedBefore930 }.count,
                greenRooms: floorRooms.filter { $0.color == .green && !$0.isCompletedBefore930 }.count,
                blueRooms: floorRooms.filter { $0.color == .blue && !$0.isCompletedBefore930 }.count,
                whiteRooms: hideWhiteRooms ? 0 : floorRooms.filter { $0.color == .white }.count,
                totalRooms: max(floorRooms.count, 1) // Минимум 1, чтобы избежать деления на ноль
            )
        }
        
        return stats
    }
    
    // Возвращает распределение по статусам
    var statusDistribution: [StatsUIStatusData] {
        // Обычные ячейки (не белые) - фильтруем, исключая отмеченные как "сделано до 9:30"
        let nonWhiteRooms = filteredRoomsByFloor.filter { !$0.isCompletedBefore930 && $0.color != .white }
        
        // Белые ячейки - все, включая отмеченные как "сделано до 9:30"
        let whiteRooms = hideWhiteRooms ? [] : filteredRoomsByFloor.filter { $0.color == .white }
        
        // Общее количество для расчета процентов
        let total = nonWhiteRooms.count + whiteRooms.count
        guard total > 0 else { return [] }
        
        let greenCount = nonWhiteRooms.filter { $0.color == .green }.count
        let blueCount = nonWhiteRooms.filter { $0.color == .blue }.count
        let redCount = nonWhiteRooms.filter { $0.color == .red }.count
        let yellowCount = nonWhiteRooms.filter { $0.color == .none }.count
        let whiteCount = whiteRooms.count
        
        // Используем сочные цвета
        let brightGreen = Color(red: 0.0, green: 0.95, blue: 0.2) // Сочный зеленый
        let brightBlue = Color(red: 0.0, green: 0.45, blue: 1.0) // Насыщенный синий
        let brightRed = Color(red: 1.0, green: 0.15, blue: 0.15) // Яркий красный
        let brightYellow = Color(red: 1.0, green: 0.85, blue: 0.0) // Яркий желтый
        
        let distribution = [
            StatsUIStatusData(color: brightGreen, count: greenCount, total: total),
            StatsUIStatusData(color: brightBlue, count: blueCount, total: total),
            StatsUIStatusData(color: brightRed, count: redCount, total: total),
            StatsUIStatusData(color: brightYellow, count: yellowCount, total: total),
            StatsUIStatusData(color: .white, count: whiteCount, total: total)
        ].filter { $0.count > 0 } // Убираем нулевые сегменты
        
        return distribution
    }
    
    // Возвращает список пурпурных комнат
    var purpleRooms: [Room] {
        filteredRoomsByFloor.filter { $0.color == .purple }
    }
    
    // Возвращает количество красных комнат
    var redRoomsCount: Int {
        filteredRoomsByFloor.filter { $0.color == .red && !$0.isCompletedBefore930 }.count
    }
    
    // Возвращает название для легенды по цвету
    func getLegendName(for color: Color) -> String {
        if color == .green {
            return "Зеленые"
        } else if color == .blue {
            return "Синие"
        } else if color == .red {
            return "Красные"
        } else if color == .yellow {
            return "none"
        } else if color == .white {
            return "Белые"
        } else {
            return ""
        }
    }
} 