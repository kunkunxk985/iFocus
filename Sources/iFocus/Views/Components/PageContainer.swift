import SwiftUI

struct PageContainer<Content: View>: View {
    private let maxWidth: CGFloat?
    private let horizontalPadding: CGFloat
    /// Space under the transparent titlebar so first content isn’t flush to the top.
    private let topPadding: CGFloat
    private let showBackground: Bool
    private let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        maxWidth: CGFloat? = 960,
        horizontalPadding: CGFloat = 40,
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
            let usableWidth = max(0, geometry.size.width - horizontalPadding * 2)

            Group {
                if let maxWidth {
                    let responsiveWidth = min(
                        usableWidth,
                        min(maxWidth * 1.8, max(maxWidth, usableWidth * 0.82))
                    )
                    content
                        .frame(maxWidth: responsiveWidth, alignment: .topLeading)
                        .padding(.horizontal, horizontalPadding)
                } else {
                    content
                        .padding(.horizontal, horizontalPadding)
                }
            }
            .padding(.top, topPadding)
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .top
            )
        }
        .background(
            showBackground
                ? AnyView(AppTheme.contentBackground(for: colorScheme))
                : AnyView(EmptyView())
        )
    }
}
