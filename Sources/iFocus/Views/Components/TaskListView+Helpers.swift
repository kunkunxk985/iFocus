import SwiftUI
let dueFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .none
    f.locale = Locale(identifier: "zh_CN")
    return f
}()

func priorityIcon(_ n: Int) -> String {
    switch n {
    case 1: return "exclamationmark.circle"
    case 2: return "exclamationmark.circle.fill"
    case 3: return "exclamationmark.triangle"
    default: return "exclamationmark.triangle.fill"
    }
}

func priorityColor(_ n: Int) -> Color {
    switch n {
    case 1: return .secondary
    case 2: return .orange
    case 3: return .red
    default: return .purple
    }
}
