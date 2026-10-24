workspace "iFocus Architecture" "Current-state, evidence-backed architecture overview of the iFocus macOS app." {

    !identifiers hierarchical

    model {
        user = person "macOS User" "Plans tasks, runs focus sessions and changes settings." "Person"
        automation = softwareSystem "Automation Clients" "Shortcuts, Alfred or scripts invoking ifocus:// URLs. Intended integration; installed clients are user-defined." "External"
        macos = softwareSystem "macOS Integration Services" "Local notifications, Login Items, Finder, System Settings, menu-bar hosting and Dock." "External"

        ifocus = softwareSystem "iFocus" "Local-first macOS focus timer and task planner. Single process, no cloud account, no network client." "System" {

            app = container "iFocus App" "Single-process SwiftUI + AppKit application." "Swift, SwiftUI, AppKit" "App" {
                appShell = component "App Shell & Navigation" "App lifecycle, window chrome, native toolbar installation, menu commands, deep-link routing, window and full-screen state." "SwiftUI App, AppKit" "UI"
                mainWindow = component "Main Window UI" "Sidebar plus Timer, Tasks, Analytics and Profile detail screens; native sidebar-toggle toolbar." "SwiftUI, AppKit toolbar" "UI"
                settingsWindow = component "Settings Window UI" "Four preference panes, native search toolbar, backup controls and notification status." "SwiftUI, AppKit toolbar" "UI"
                menuBar = component "Menu Bar Extra" "NSStatusItem with live countdown and quick timer/task actions." "AppKit" "UI"
                stores = component "Domain Stores" "TimerStore, TaskStore, SettingsStore and AnalyticsDashboardModel; observable state and orchestration." "Swift ObservableObject" "State"
                services = component "Local Services" "Backup export/restore, pre-upgrade copies and login-item registration. StudyLog writer remains, but the shipped app does not call it." "Swift, ServiceManagement" "Service"
                core = component "iFocusCore" "Foundation-only pure logic for filtering, search, statistics, formatting and backup formats. Study-plan templates and the old study-log format stay for existing data and tests." "Swift library" "Core"
            }

            dataFiles = container "Local Data Files" "tasks.json, focus_sessions.json, app_state.json and timer_session.json in ~/Library/Application Support/iFocus." "JSON files" "Database"
            preferences = container "Preferences" "UserDefaults-backed settings and main-window layout." "UserDefaults" "Database"
            studyLog = container "Study Log Export" "Legacy readable mirror under ~/StudyLog. The writer remains, but the shipped app does not pass a directory, so it is not regenerated." "CSV, Markdown" "Database"
            backups = container "Backup Packages" "User-selected folder with JSON payloads, settings, avatar and manifest.json." "JSON files" "Database"
        }

        # Context-level relationships
        user -> ifocus "Plans tasks, runs focus sessions and changes settings"
        automation -> ifocus "Sends ifocus:// deep links" "URL scheme"
        ifocus -> macos "Sends notifications, registers login items and opens Finder or System Settings"
        user -> macos "Approves notification/login-item permissions and manages system Focus"

        # Container-level relationships
        user -> ifocus.app "Uses the main window, settings window and menu bar"
        automation -> ifocus.app "Sends ifocus:// deep links" "URL scheme"
        ifocus.app -> ifocus.dataFiles "Reads and writes tasks, sessions, active task and timer snapshot" "atomic file I/O"
        ifocus.app -> ifocus.preferences "Reads and writes preferences and window layout" "UserDefaults"
        ifocus.app -> ifocus.studyLog "Can write a readable study log when a directory is injected; production does not" "background queue"
        ifocus.app -> ifocus.backups "Exports and restores backup folders" "file I/O"
        ifocus.app -> macos "Uses notifications, login items, Finder, System Settings and Dock"

        # Component-level relationships
        ifocus.app.appShell -> ifocus.app.mainWindow "Hosts"
        ifocus.app.appShell -> ifocus.app.settingsWindow "Opens via menu command or ⌘,"
        ifocus.app.appShell -> ifocus.app.menuBar "Installs status item"
        ifocus.app.appShell -> ifocus.app.stores "Creates and injects stores"
        ifocus.app.appShell -> ifocus.app.services "Runs pre-upgrade guard at launch"

        ifocus.app.mainWindow -> ifocus.app.stores "Reads state; sends timer, task and navigation commands"
        ifocus.app.settingsWindow -> ifocus.app.stores "Reads and writes preferences; reads task counts and timer status"
        ifocus.app.settingsWindow -> ifocus.app.services "Exports/restores backups and opens login-item settings"
        ifocus.app.menuBar -> ifocus.app.stores "Observes timer/task/settings and sends timer or task actions"

        ifocus.app.stores -> ifocus.app.core "Uses filtering, search, statistics, formatting and study-plan helpers"
        ifocus.app.services -> ifocus.app.core "Uses backup, study-log and plan formats"
        ifocus.app.stores -> ifocus.app.services "Applies the login-item preference. StudyLog export runs only when a directory was injected"
        ifocus.app.services -> ifocus.app.stores "Reads and restores task/session/settings data for backups"

        ifocus.app.stores -> ifocus.app.dataFiles "Persists tasks, sessions, active task and timer snapshots"
        ifocus.app.stores -> ifocus.app.preferences "Persists settings and window state"
        ifocus.app.services -> ifocus.app.dataFiles "Copies JSON before upgrades; restores backup payloads"
        ifocus.app.services -> ifocus.app.studyLog "Writes sessions.csv and weekly Markdown"
        ifocus.app.services -> ifocus.app.backups "Writes and reads backup packages"

        ifocus.app.stores -> macos "Schedules timer notifications and updates the Dock badge"
        ifocus.app.services -> macos "Registers/unregisters the login item and opens System Settings"

        user -> ifocus.app.mainWindow "Interacts with"
        user -> ifocus.app.settingsWindow "Changes preferences"
        user -> ifocus.app.menuBar "Quick timer actions"
        automation -> ifocus.app.appShell "Delivers ifocus:// URLs" "URL scheme"
    }

    views {
        systemContext ifocus "SystemContext" "iFocus, its user and external systems." {
            include *
            autoLayout lr
        }

        container ifocus "Containers" "The app and its local data stores." {
            include *
            autoLayout lr
        }

        component ifocus.app "Components" "Responsibilities inside the iFocus app container." {
            include *
            autoLayout tb
        }

        styles {
            element "Person" {
                shape person
                background #08427B
                color #FFFFFF
            }
            element "System" {
                background #1F2937
                color #FFFFFF
            }
            element "External" {
                background #8B8B8B
                color #FFFFFF
            }
            element "App" {
                background #2563EB
                color #FFFFFF
            }
            element "Database" {
                shape cylinder
                background #0F766E
                color #FFFFFF
            }
            element "UI" {
                background #3B82F6
                color #FFFFFF
            }
            element "State" {
                background #8B5CF6
                color #FFFFFF
            }
            element "Service" {
                background #F97316
                color #FFFFFF
            }
            element "Core" {
                background #10B981
                color #FFFFFF
            }
        }
    }
}
