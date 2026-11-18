import SwiftUI

/// Shared Helvetica Neue typography and technical labels.
enum BewieTypography {
    static let title = Font.custom("HelveticaNeue-Medium", size: 34, relativeTo: .largeTitle)
    static let sectionTitle = Font.custom("HelveticaNeue-Medium", size: 22, relativeTo: .title2)
    static let heading = Font.custom("HelveticaNeue-Bold", size: 17, relativeTo: .headline)
    static let body = Font.custom("HelveticaNeue", size: 17, relativeTo: .body)
    static let subheadline = Font.custom("HelveticaNeue", size: 15, relativeTo: .subheadline)
    static let footnote = Font.custom("HelveticaNeue", size: 13, relativeTo: .footnote)
    static let caption = Font.custom("HelveticaNeue", size: 12, relativeTo: .caption)
    static let caption2 = Font.custom("HelveticaNeue", size: 11, relativeTo: .caption2)
    static let technical = Font.custom("PTMono-Regular", size: 12, relativeTo: .caption)
}

extension View {
    func bewieNavigationTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(BewieTypography.heading)
                        .lineLimit(1)
                }
            }
    }
}
