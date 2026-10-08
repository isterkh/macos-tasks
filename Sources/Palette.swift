import SwiftUI

struct Pastel: Identifiable {
    let id: String
    let name: String
    let color: Color

    static let all: [Pastel] = [
        .init(id: "lavender", name: "Лаванда", color: Color(red: 0.73, green: 0.68, blue: 0.91)),
        .init(id: "blue", name: "Небо", color: Color(red: 0.58, green: 0.77, blue: 0.92)),
        .init(id: "mint", name: "Мята", color: Color(red: 0.56, green: 0.82, blue: 0.75)),
        .init(id: "peach", name: "Персик", color: Color(red: 0.98, green: 0.73, blue: 0.62)),
        .init(id: "rose", name: "Роза", color: Color(red: 0.93, green: 0.67, blue: 0.75)),
        .init(id: "lemon", name: "Лимон", color: Color(red: 0.93, green: 0.83, blue: 0.53))
    ]

    static func color(_ id: String?) -> Color {
        all.first(where: { $0.id == id })?.color ?? .gray.opacity(0.45)
    }
}

struct PalettePicker: View {
    @Binding var selection: String?
    var allowsNone = false

    var body: some View {
        HStack(spacing: 8) {
            if allowsNone {
                Button {
                    selection = nil
                } label: {
                    Image(systemName: "slash.circle")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Без цвета")
                .accessibilityLabel("Без цвета")
            }
            ForEach(Pastel.all) { pastel in
                Button {
                    selection = pastel.id
                } label: {
                    Circle()
                        .fill(pastel.color)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if selection == pastel.id {
                                Circle().strokeBorder(.primary, lineWidth: 2).padding(2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(pastel.name)
                .accessibilityLabel(pastel.name)
            }
        }
    }
}
