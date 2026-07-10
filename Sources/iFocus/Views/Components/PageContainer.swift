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
        Group {
            if let maxWidth {
                content
                    .frame(maxWidth: maxWidth, alignment: .topLeading)
                    .padding(.horizontal, horizontalPadding)
            } else {
                content
                    .padding(.horizontal, horizontalPadding)
            }
        }
        .padding(.top, topPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            showBackground
                ? AnyView(AppTheme.contentBackground(for: colorScheme))
                : AnyView(EmptyView())
        )
    }
}
