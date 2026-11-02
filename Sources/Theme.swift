import SwiftUI

/// The app's look: a warm sunset palette (red, orange, amber, yellow, greens), priority colors,
/// and a monospaced "label" voice for metadata.
enum Theme {
    static let red = Color(red: 0.81, green: 0.31, blue: 0.23)      // #CF4F3A
    static let ember = Color(red: 0.83, green: 0.37, blue: 0.22)    // #D35F37
    static let amber = Color(red: 0.88, green: 0.55, blue: 0.22)    // #E08C38
    static let sun = Color(red: 0.92, green: 0.72, blue: 0.25)      // #EBB840
    static let leaf = Color(red: 0.56, green: 0.74, blue: 0.31)     // #8FBD4E
    static let forest = Color(red: 0.27, green: 0.53, blue: 0.32)   // #458752

    static let accent = ember

    /// Gutter shared by the title, the task rows and the add box, so they line up.
    static let gutter: CGFloat = 28

    static func priorityColor(_ p: Int?) -> Color {
        switch p {
        case 0: return red
        case 1: return amber
        case 2: return sun
        case 3: return leaf
        default: return Color.secondary.opacity(0.6)
        }
    }

    /// Small caps-style mono label: dates, projects, tags.
    static func label(_ size: CGFloat = 10.5) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    static let headline = Font.system(size: 38, weight: .black, design: .default)
}

/// A tight mono tag, used for dates, projects, labels and priorities.
struct Tag: View {
    var text: String
    var symbol: String? = nil
    var color: Color = .secondary
    var filled = false

    var body: some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
            Text(text.uppercased()).font(Theme.label()).tracking(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .foregroundStyle(filled ? Color.white : color)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(filled ? color : color.opacity(0.12))
        )
    }
}
