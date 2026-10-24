import SwiftUI

struct SidebarItem: Identifiable {
    /// Stable identity so ForEach does not recreate rows every body pass.
    var id: AppScreen { screen }
    let title: String
    let screen: AppScreen
    let badge: String?
    let icon: String
    var accentColor: Color? = nil
}
