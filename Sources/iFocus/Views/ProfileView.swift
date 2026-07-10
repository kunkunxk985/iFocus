import SwiftUI
import AppKit
import iFocusCore

/// Profile screen — thin composition of focused subviews.
struct ProfileView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var taskStore: TaskStore
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
        var minutesStats = [TaskCategory: Int]()
        var countStats = [TaskCategory: Int]()
        for session in taskStore.focusSessions {
            if let category = session.taskCategory {
                minutesStats[category, default: 0] += session.durationMinutes
                countStats[category, default: 0] += 1
            } else if let taskId = session.taskId,
                      let task = taskStore.tasks.first(where: { $0.id == taskId }) {
                minutesStats[task.category, default: 0] += session.durationMinutes
                countStats[task.category, default: 0] += 1
            } else {
                minutesStats[.other, default: 0] += session.durationMinutes
                countStats[.other, default: 0] += 1
            }
        }
        return TaskCategory.allCases.map { cat in
            ProfileCategoryStat(
                category: cat,
                minutes: minutesStats[cat] ?? 0,
                count: countStats[cat] ?? 0
            )
        }
        .sorted { $0.minutes > $1.minutes }
    }
    
    var body: some View {
        PageContainer(maxWidth: 900, horizontalPadding: 40) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ProfileHeaderBar(
                        onShare: shareReportViaEmail,
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
                    .padding(.top, 24)
                    .padding(.bottom, 56)
                }
            }
            .softScroll()
        }
        .id(colorScheme)
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
    
    private func shareReportViaEmail() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySessions = taskStore.focusSessions.filter { $0.timestamp >= today }
        let todayPomodorosCount = todaySessions.count
        let todayMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        let dateStr = formatter.string(from: Date())
        
        var bodyText = """
        你好！这是 \(displayName) 在 \(dateStr) 的 iFocus 专注日报：
        
        - 今日完成番茄钟：\(todayPomodorosCount) 个
        - 今日累计专注时间：\(todayMinutes) 分钟
        - 当前连续专注天数：\(streakInfo.current) 天
        
        分类专注明细：
        """
        
        let stats = categoryStats.filter { $0.minutes > 0 }
        if stats.isEmpty {
            bodyText += "\n- 暂无分类专注数据（自由专注）"
        } else {
            for item in stats {
                bodyText += "\n- \(item.category.rawValue)：\(item.minutes) 分钟"
            }
        }
        
        bodyText += "\n\n合理规划时间，保持高效专注！\n-- 来自 iFocus macOS 客户端"
        
        let subject = "iFocus 专注日报 - \(dateStr)"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = bodyText.addingPercentEncoding(withAllowedCharacters: allowed) else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(subject)\n\n\(bodyText)", forType: .string)
            return
        }
        let urlString = "mailto:?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: urlString), urlString.count < 7000 {
            NSWorkspace.shared.open(url)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("\(subject)\n\n\(bodyText)", forType: .string)
        }
    }
}
