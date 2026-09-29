import SwiftUI

enum AppScreen: Hashable {
    case todayTask, tomorrowTask, weekTask, plannedTask, completedTask, inboxTask
    case timer, analytics, profile
}

class ContentViewState: ObservableObject {
    @Published var selectedScreen: AppScreen? = .timer
    @Published var shouldFocusQuickAdd: Bool = false
    @Published var shouldFocusSearch: Bool = false
}

struct SidebarItem: Identifiable {
    /// Stable identity so ForEach does not recreate rows every body pass.
    var id: AppScreen { screen }
    let title: String
    let screen: AppScreen
    let badge: String?
    let icon: String
    var accentColor: Color? = nil
}
