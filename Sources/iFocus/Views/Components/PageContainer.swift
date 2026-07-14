import SwiftUI

struct PageContainer<Content: View>: View {
    private let maxWidth: CGFloat?
    private let horizontalPadding: CGFloat?
    /// Space under the transparent titlebar so first content isn’t flush to the top.
    private let topPadding: CGFloat
    private let showBackground: Bool
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settings: SettingsStore

    init(
        maxWidth: CGFloat? = 960,
        horizontalPadding: CGFloat? = nil,
        topPadding: CGFloat = AppTheme.detailTopInset,
        showBackground: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.maxWidth = maxWidth
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.showBackground = showBackground
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = WindowLayoutMetrics(
                width: geometry.size.width,
                height: geometry.size.height,
                densityScale: settings.uiDensity.scale
            )
            let pad = horizontalPadding ?? layout.pageHorizontalPadding
            let usableWidth = max(0, geometry.size.width - pad * 2)
            let cap = maxWidth.map { min($0 * 1.15, layout.pageContentMaxWidth) } ?? layout.pageContentMaxWidth

            Group {
                if maxWidth != nil {
                    let responsiveWidth = min(usableWidth, max(cap * 0.85, min(cap, usableWidth * 0.9)))
                    content
                        .frame(maxWidth: responsiveWidth, alignment: .topLeading)
                        .padding(.horizontal, pad)
                } else {
                    content
                        .padding(.horizontal, pad)
                }
            }
            .padding(.top, topPadding)
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .top
            )
            .animation(.easeInOut(duration: 0.16), value: layout.scale)
        }
        .background(
            showBackground
                ? AnyView(AppTheme.contentBackground(for: colorScheme))
                : AnyView(EmptyView())
        )
    }
}
