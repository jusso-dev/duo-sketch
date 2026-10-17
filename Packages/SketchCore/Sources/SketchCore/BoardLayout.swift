/// Mirrors SwiftUI's `UserInterfaceSizeClass` so layout rules can be tested on Linux.
public enum SizeClass: Sendable, Equatable {
    case compact
    case regular
}

/// How the board is arranged on screen.
public enum BoardLayout: Sendable, Equatable {
    /// Canvas on top, dials in the bottom corners. Phones in portrait and the Duo outer display.
    case portrait
    /// Canvas in the middle, one dial on each side. Phones in landscape.
    case landscape
    /// Big canvas with roomy dials. iPhone Duo inner display, fully open.
    case wide
    /// Canvas on the upper half, dials on the lower half. iPhone Duo half open.
    case easel

    /// Partial hinge angles that use the easel layout. Below the lower bound the
    /// phone is effectively shut (a hinge settling after closing reports a degree
    /// or two), and above the upper bound it is effectively flat. The lower bound
    /// is the same angle `FoldClearPolicy` treats as a reopen.
    public static let easelAngles: ClosedRange<Double> = FoldPosture.reopenAngleDegrees...160

    /// Chooses a layout. Size classes drive layout; the hinge only adds easel mode.
    public static func choose(horizontal: SizeClass, vertical: SizeClass, fold: FoldPosture) -> BoardLayout {
        if case .partiallyOpen(let angle) = fold, easelAngles.contains(angle) { return .easel }
        switch (horizontal, vertical) {
        case (.regular, .regular): return .wide
        case (_, .compact): return .landscape
        case (.compact, .regular), (.regular, _): return .portrait
        }
    }
}
