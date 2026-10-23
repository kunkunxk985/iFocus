import SwiftUI
import iFocusCore

/// Profile screen — thin composition of focused subviews.
struct ProfileView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var timerStore: TimerStore
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isEditing = false
    @State private var tempUsername = ""
    
    private var displayName: String {
        let name = settings.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "小番茄" : name
    }
    
    private var sessionTimestamps: [Date] {
        taskStore.focusSessions.map(\.timestamp)
    }
    
    private var streakInfo: (current: Int, longest: Int) {
        FocusStats.streaks(sessionTimestamps: sessionTimestamps)
    }
    
    private var totalMinutes: Int {
        taskStore.focusSessions.reduce(0) { $0 + $1.durationMinutes }
    }
    
    private var todayPomodoros: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return taskStore.focusSessions.filter { $0.timestamp >= today }.count
    }
    
    private var heatmapGrid: [[FocusStats.ContributionCell]] {
        let pairs = taskStore.focusSessions.map { ($0.timestamp, $0.durationMinutes) }
        let byDay = FocusStats.minutesByDay(sessions: pairs)
        return FocusStats.contributionGrid(minutesByDay: byDay)
    }
    
    private var heatmapMonthLabels: [Int: String] {
        FocusStats.monthLabels(for: heatmapGrid)
    }
    
    private var categoryStats: [ProfileCategoryStat] {
        var minutesByID = [String: Int]()
        var countByID = [String: Int]()
        var categoriesByID = Dictionary(
            uniqueKeysWithValues: taskStore.categoriesInUse.map { ($0.id, $0) }
        )
        for session in taskStore.focusSessions {
            let category: TaskCategory
            if let stored = session.taskCategory {
                category = stored
            } else if let taskId = session.taskId,
                      let task = taskStore.tasks.first(where: { $0.id == taskId }) {
                category = task.category
            } else {
                category = .other
            }
            if categoriesByID[category.id] == nil {
                categoriesByID[category.id] = category
            }
            minutesByID[category.id, default: 0] += session.durationMinutes
            countByID[category.id, default: 0] += 1
        }
        return taskStore.categoriesInUse.map { cat in
            ProfileCategoryStat(
                category: categoriesByID[cat.id] ?? cat,
                minutes: minutesByID[cat.id] ?? 0,
                count: countByID[cat.id] ?? 0
            )
        }
        .sorted { $0.minutes > $1.minutes }
    }
    
    var body: some View {
        PageContainer(maxWidth: 900, horizontalPadding: 40) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProfileHeaderBar(
                        onEdit: {
                            tempUsername = displayName
                            isEditing = true
                        }
                    )
                    
                    ProfileIdentityBlock(
                        avatarPath: settings.avatarPath,
                        avatarColorIndex: settings.avatarColorIndex,
                        username: displayName
                    )
                    
                    ProfileStatsRow(
                        todayPomodoros: todayPomodoros,
                        totalMinutes: totalMinutes,
                        totalPomodoros: taskStore.focusSessions.count,
                        currentStreak: streakInfo.current,
                        longestStreak: streakInfo.longest
                    )
                    
                    ProfileHeatmapCard(
                        grid: heatmapGrid,
                        monthLabels: heatmapMonthLabels
                    )
                    
                    HStack(alignment: .top, spacing: 20) {
                        ProfileInsightsCard(
                            maxSingleFocusSession: taskStore.focusSessions.map(\.durationMinutes).max() ?? 0,
                            averageDailyLabel: FocusStats.formatTotalMinutes(
                                FocusStats.averageDailyFocusMinutes(
                                    sessionTimestamps: sessionTimestamps,
                                    totalMinutes: totalMinutes
                                )
                            ),
                            peakHours: FocusStats.peakFocusHoursString(sessionTimestamps: sessionTimestamps),
                            completionRate: FocusStats.completionRate(
                                total: taskStore.tasks.count,
                                completed: taskStore.tasks.filter(\.isCompleted).count
                            )
                        )
                        .frame(maxWidth: .infinity)
                        
                        ProfileCategoriesCard(
                            stats: categoryStats,
                            isEmpty: taskStore.focusSessions.isEmpty
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, timerStore.isSessionInProgress ? 96 : 32)
            }
            .softScroll()
        }
        .overlay {
            if isEditing {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { isEditing = false }

                    EditProfileSheet(
                        tempUsername: $tempUsername,
                        isPresented: $isEditing
                    )
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
                .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isEditing)
    }
}
