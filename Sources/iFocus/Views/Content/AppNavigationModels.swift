import SwiftUI

enum AppScreen: Hashable {
    case todayTask, tomorrowTask, weekTask, plannedTask, completedTask, inboxTask
    case timer, analytics, profile
}

class ContentViewState: ObservableObject {
    @Published var selectedScreen: AppScreen? = .timer
}

struct SidebarItem: Identifiable {
    /// Stable identity so ForEach does not recreate rows every body pass.
    var id: AppScreen { screen }
    let title: String
    let screen: AppScreen
    let badge: String?
    let icon: String
    let tint: Color
}
