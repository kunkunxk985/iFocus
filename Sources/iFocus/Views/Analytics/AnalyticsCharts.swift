import SwiftUI
import Charts
import iFocusCore

// MARK: - Today timeline (block view)

struct TodayTimelineView: View {
    let blocks: [FocusStats.TimelineBlock]
    @Environment(\.colorScheme) private var colorScheme
    
    private let hourLabels = [0, 6, 12, 18, 24]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = max(36, geo.size.height - 18)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.separator(for: colorScheme).opacity(0.35))
                        .frame(height: h)
                    
                    ForEach(blocks) { block in
                        let prog = block.dayProgress()
                        let x = prog.start * w
                        let width = max(8, (prog.end - prog.start) * w)
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AppTheme.accent.opacity(0.85))
                                .frame(width: width, height: h * 0.72)
                                .overlay(
                                    Text(block.title)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 4)
                                        .opacity(width > 48 ? 1 : 0)
                                )
                                .help("\(block.title) · \(block.minutes) 分")
                        }
                        .offset(x: x, y: h * 0.14)
                    }
                }
            }
            
            HStack {
                ForEach(hourLabels, id: \.self) { hour in
                    Text(String(format: "%02d", hour == 24 ? 24 : hour))
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    if hour < 24 { Spacer(minLength: 0) }
                }
            }
        }
    }
}

// MARK: - Today hour distribution

struct TodayHourChart: View {
    let hourMinutes: [Int]
    
    private struct HourBar: Identifiable {
        let id: Int
        let label: String
        let minutes: Int
    }
    
    private var data: [HourBar] {
        hourMinutes.enumerated().map { index, mins in
            HourBar(
                id: index,
                label: index % 3 == 0 ? String(format: "%02d", index) : "",
                minutes: mins
            )
        }
    }
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("时", item.id),
                y: .value("分钟", item.minutes)
            )
            .foregroundStyle(AppTheme.accent.gradient)
            .cornerRadius(2)
        }
        .chartXScale(domain: 0...23)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) {
                        Text(String(format: "%02d", h))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Weekly Focus Chart

struct WeeklyFocusChart: View {
    let sessions: [FocusSession]
    var dayCount: Int = 7
    @Environment(\.colorScheme) private var colorScheme

    struct DayFocus: Identifiable {
        var id: String { label }
        let label: String
        let minutes: Int
    }

    private var chartData: [DayFocus] {
        let calendar = Calendar.current
        var data: [DayFocus] = []
        let today = calendar.startOfDay(for: Date())
        let days = max(1, min(dayCount, 62))

        let formatter = DateFormatter()
        formatter.dateFormat = days > 14 ? "M/d" : "MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")

        for i in (0..<days).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let daySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            let mins = daySessions.reduce(0) { $0 + $1.durationMinutes }
            data.append(DayFocus(label: formatter.string(from: day), minutes: mins))
        }
        return data
    }

    var body: some View {
        Chart {
            ForEach(chartData) { item in
                BarMark(
                    x: .value("日期", item.label),
                    y: .value("分钟", item.minutes)
                )
                .foregroundStyle(AppTheme.accent.gradient)
                .cornerRadius(4)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
    }
}
