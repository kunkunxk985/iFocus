import SwiftUI

/// Pages the sidebar, menus, and deep links can open.
/// Lives with navigation so the app shell does not depend on a view file for its route names.
enum AppScreen: Hashable {
    case todayTask, tomorrowTask, weekTask, plannedTask, completedTask, inboxTask
    case timer, analytics, profile
}

class ContentViewState: ObservableObject {
    @Published var selectedScreen: AppScreen? = .timer
    @Published var shouldFocusQuickAdd: Bool = false
    @Published var shouldFocusSearch: Bool = false
}
