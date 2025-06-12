import SwiftUI

struct RoomListCell: View {
    let room: Room
    let fontColor: String
    let getTranslation: (String) -> String

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                let sections = numberOfSections()
                let width = geometry.size.width / CGFloat(sections)

                // Первая часть — цвет этажа
                cellSection(
                    color: floorColor().opacity(0.8),
                    width: width,
                    content: {
                        Text(room.number)
                            .font(.title)
                            .bold()
                            .foregroundColor(.black)
                    }
                )

                // Если есть время красного статуса
                if let redTime = room.redTimestamp {
                    cellSection(
                        color: Color.red.opacity(0.8),
                        width: width,
                        content: {
                            Text(formattedTime(redTime))
                                .font(.title)
                                .bold()
                                .foregroundColor(.black)
                        }
                    )
                }

                // Если есть время зелёного статуса
                if let greenTime = room.greenTimestamp {
                    cellSection(
                        color: Color.green.opacity(0.8),
                        width: width,
                        content: {
                            Text(formattedTime(greenTime))
                                .font(.title)
                                .bold()
                                .foregroundColor(.black)
                        }
                    )
                }
            }
            .frame(height: 60)
        }
        .frame(height: 60)
    }

    func cellSection<Content: View>(color: Color, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            color
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width, height: 60)
    }

    func floorColor() -> Color {
        guard let floorNumber = Int(room.number.prefix(1)) else {
            return Color.gray.opacity(0.8)
        }

        switch floorNumber {
        case 2:
            return Color.cyan.opacity(0.8)
        case 3:
            return Color.orange.opacity(0.8)
        case 4:
            return Color.pink.opacity(0.8)
        case 5:
            return Color.yellow.opacity(0.8)
        default:
            return Color.gray.opacity(0.8)
        }
    }

    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func numberOfSections() -> Int {
        var count = 1 // Цвет этажа
        if room.redTimestamp != nil {
            count += 1
        }
        if room.greenTimestamp != nil {
            count += 1
        }
        return count
    }
}
