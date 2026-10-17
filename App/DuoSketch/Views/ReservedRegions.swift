import SwiftUI
import SketchCore

/// The parts of the display iPhone Duo's hardware reserves, in a view's own
/// coordinates: the fold while the phone is partly open (divisions) and the
/// cameras (occlusions). Only active regions are kept. Empty before iOS 27.1
/// and on phones without these regions.
///
/// - https://developer.apple.com/documentation/swiftui/reservedregion
/// - https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo
struct ReservedRegions: Equatable {
    var divisions: [LayoutRect] = []
    var occlusions: [LayoutRect] = []

    init(divisions: [LayoutRect] = [], occlusions: [LayoutRect] = []) {
        self.divisions = divisions
        self.occlusions = occlusions
    }

    init(_ proxy: GeometryProxy) {
        if #available(iOS 27.1, *) {
            divisions = proxy.reservedRegions(kind: .division)
                .filter(\.isActive)
                .map { LayoutRect($0.frame) }
            occlusions = proxy.reservedRegions(kind: .occlusion)
                .filter(\.isActive)
                .map { LayoutRect($0.frame) }
        }
    }
}

extension LayoutRect {
    init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}

/// Outlines of the reserved regions, shown with `-foldDebug` so the fold and
/// cameras can be checked against the layout on the iPhone Duo simulator.
struct ReservedRegionOutlines: View {
    let regions: ReservedRegions

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(regions.divisions.enumerated()), id: \.offset) { _, rect in
                outline(rect, colour: .yellow)
            }
            ForEach(Array(regions.occlusions.enumerated()), id: \.offset) { _, rect in
                outline(rect, colour: .cyan)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func outline(_ rect: LayoutRect, colour: Color) -> some View {
        Rectangle()
            .strokeBorder(colour, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .background(colour.opacity(0.15))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
