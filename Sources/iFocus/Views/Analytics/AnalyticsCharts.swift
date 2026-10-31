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
                        .fill(AppTheme.separatorLow(for: colorScheme).opacity(colorScheme == .light ? 0.7 : 0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.separatorLow(for: colorScheme), lineWidth: 0.5)
                        )
                        .frame(height: h)
                    
                    ForEach(blocks) { block in
                        let prog = block.dayProgress()
                        let x = prog.start * w
                        let width = max(10, (prog.end - prog.start) * w)
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(AppTheme.accent)
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
                        .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
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
    @Environment(\.colorScheme) private var colorScheme
    
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
            .foregroundStyle(AppTheme.accent)
            .cornerRadius(4, style: .continuous)
        }
        .chartXScale(domain: 0...23)
        .chartYScale(domain: 0...max(60, hourMinutes.max() ?? 0))
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) {
                        Text(String(format: "%02d", h))
                            .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AppTheme.separatorLow(for: colorScheme).opacity(0.4))
                AxisValueLabel {
                    if let m = value.as(Int.self) {
                        Text("\(m)")
                            .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.8))
                    }
                }
            }
        }
    }
}

// MARK: - Weekly Focus Chart

struct WeeklyFocusChart: View {
    let sessions: [FocusSession]
    var dayCount: Int = 7
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredDay: DayFocus? = nil

    struct DayFocus: Identifiable {
        var id: Date { date }
        let date: Date
        let label: String
        let minutes: Int
        let pomodoros: Int
    }

    private var strideDays: Int {
        if dayCount >= 45 {
            return 10
        } else if dayCount >= 20 {
            return 5
        } else if dayCount >= 10 {
            return 2
        } else {
            return 1
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dayCount > 14 ? "M/d" : "MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }

    private var weeklyFocusData: [DayFocus] {
        let calendar = Calendar.current
        var data: [DayFocus] = []
        let today = calendar.startOfDay(for: Date())
        let days = max(1, min(dayCount, 62))
        let formatter = dateFormatter

        for i in (0..<days).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let daySessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            let mins = daySessions.reduce(0) { $0 + max(0, $1.durationMinutes) }
            let pomos = daySessions.count
            data.append(DayFocus(date: day, label: formatter.string(from: day), minutes: mins, pomodoros: pomos))
        }
        return data
    }

    private var chartData: [DayFocus] { weeklyFocusData }

    var body: some View {
        let formatter = dateFormatter
        Chart {
            if let hovered = hoveredDay {
                RuleMark(x: .value("选中日期", hovered.date, unit: .day))
                    .foregroundStyle(AppTheme.accent.opacity(0.16))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            ForEach(chartData) { item in
                BarMark(
                    x: .value("日期", item.date, unit: .day),
                    y: .value("分钟", item.minutes)
                )
                .foregroundStyle(AppTheme.accent)
                .cornerRadius(4, style: .continuous)
                .opacity(hoveredDay == nil || hoveredDay?.id == item.id ? 1.0 : 0.45)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(AppTheme.separatorLow(for: colorScheme).opacity(0.4))
                AxisValueLabel {
                    if let m = value.as(Int.self) {
                        Text("\(m)")
                            .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme).opacity(0.8))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideDays)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(formatter.string(from: d))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.secondaryText(for: colorScheme))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            handleHover(phase: phase, proxy: proxy, geo: geo)
                        }

                    if let hovered = hoveredDay {
                        let pt = tooltipPosition(for: hovered, proxy: proxy, geo: geo)
                        tooltipView(for: hovered)
                            .position(pt)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func handleHover(phase: HoverPhase, proxy: ChartProxy, geo: GeometryProxy) {
        switch phase {
        case .active(let location):
            let plot = resolvePlotArea(proxy: proxy, geo: geo)
            guard plot.contains(location) else {
                if hoveredDay != nil {
                    withAnimation(AppTheme.springInteractive) { hoveredDay = nil }
                }
                return
            }
            let relX = location.x - plot.origin.x
            guard let date = proxy.value(atX: relX, as: Date.self) else { return }
            let cal = Calendar.current
            let matched = chartData.first { cal.isDate($0.date, inSameDayAs: date) }
                ?? chartData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
            if let newDay = matched, hoveredDay?.id != newDay.id {
                withAnimation(AppTheme.springInteractive) {
                    hoveredDay = newDay
                }
            }
        case .ended:
            if hoveredDay != nil {
                withAnimation(AppTheme.springInteractive) {
                    hoveredDay = nil
                }
            }
        }
    }

    private func tooltipView(for item: DayFocus) -> some View {
        Text(Self.formatTooltip(date: item.date, minutes: item.minutes, pomodoros: item.pomodoros))
            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundColor(AppTheme.primaryText(for: colorScheme))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(AppTheme.cardBackground(for: colorScheme))
            )
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.separatorLow(for: colorScheme).opacity(colorScheme == .light ? 0.8 : 0.4), lineWidth: 0.8)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.38),
                radius: 5,
                x: 0,
                y: 2
            )
    }

    private func tooltipPosition(for item: DayFocus, proxy: ChartProxy, geo: GeometryProxy) -> CGPoint {
        let plot = resolvePlotArea(proxy: proxy, geo: geo)
        let barX = proxy.position(forX: item.date) ?? (plot.width / 2)
        let rawCenterX = plot.origin.x + barX
        let minMargin: CGFloat = 105
        let clampedX: CGFloat
        if geo.size.width > minMargin * 2 {
            clampedX = min(max(rawCenterX, minMargin), geo.size.width - minMargin)
        } else {
            clampedX = geo.size.width / 2
        }
        let topY: CGFloat = plot.origin.y + 14
        return CGPoint(x: clampedX, y: topY)
    }

    private func resolvePlotArea(proxy: ChartProxy, geo: GeometryProxy) -> CGRect {
        #if compiler(>=5.9)
        if #available(macOS 14.0, *) {
            if let anchor = proxy.plotFrame {
                return geo[anchor]
            }
        }
        #endif
        return geo[proxy.plotAreaFrame]
    }

    static func formatTooltip(
        date: Date,
        minutes: Int,
        pomodoros: Int,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let datePart = formatter.string(from: date)

        let safeMinutes = max(0, minutes)
        let timePart: String
        if safeMinutes < 60 {
            timePart = "\(safeMinutes)分"
        } else {
            let h = safeMinutes / 60
            let m = safeMinutes % 60
            if m == 0 {
                timePart = "\(h)小时"
            } else {
                timePart = "\(h)小时\(m)分"
            }
        }
        return "\(datePart) · \(timePart) · \(max(0, pomodoros))个番茄"
    }
}
