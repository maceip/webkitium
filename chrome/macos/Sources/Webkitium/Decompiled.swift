import Foundation
import CoreGraphics

/// Constants preserved verbatim from radare2 decompilation of `Safari.framework` against
/// `/private/tmp/dsc-out/.../Safari` (macOS 26 Tahoe build). Keeping them as a single
/// file makes the provenance clear and lets us trust the values across the rewrite.
enum SafariDecompiled {

    // MARK: - TabBarView width algorithm (`_buttonWidthForNumberOfButtons:...`)
    /// Minimum width of the selected tab in the strip — `0x405e000000000000` in __DATA_CONST.
    static let selectedTabMinWidth: CGFloat = 120.0

    /// Animation duration used by `_animateButtonLayout:` for tab reorder/compression.
    /// 0x1b84d8bf0 → 0.2.
    static let focusAnimationDuration: TimeInterval = 0.2

    /// Port of `-[TabBarView _buttonWidthForNumberOfButtons:selectedButtonIndex:inWidth:
    /// remainderWidth:selectedButtonWidth:]`. Returns the per-tab widths plus leftover
    /// remainder pixels for the strip layout.
    struct ComputedWidths { let other: CGFloat; let selected: CGFloat; let remainder: CGFloat }
    static func computeButtonWidths(numberOfButtons N: Int, selectedIndex: Int?,
                                     inWidth: CGFloat) -> ComputedWidths {
        guard N > 0 else { return ComputedWidths(other: 0, selected: 0, remainder: 0) }
        let baseWidth = floor(inWidth / CGFloat(N))
        var selectedWidth = max(baseWidth, selectedTabMinWidth)
        if N == 1, selectedIndex != nil { selectedWidth = baseWidth }
        if N == 1 {
            return ComputedWidths(other: baseWidth, selected: selectedWidth,
                                   remainder: floor(inWidth - baseWidth * CGFloat(N)))
        }
        let remainingAfterSelected = inWidth - selectedWidth
        let otherWidth = floor(remainingAfterSelected / CGFloat(N - 1))
        let otherRemainder = remainingAfterSelected - otherWidth * CGFloat(N - 1)
        if selectedWidth != baseWidth {
            return ComputedWidths(other: otherWidth, selected: selectedWidth,
                                   remainder: floor(otherRemainder))
        } else {
            return ComputedWidths(other: baseWidth, selected: selectedWidth,
                                   remainder: floor(inWidth - baseWidth * CGFloat(N)))
        }
    }

    // MARK: - VisualTabPicker animation (`+[VisualTabPickerViewController springAnimationForVisualTabPicker]`
    /// + `tabPickerAnimationDuration` at Safari 0x1b828caa8 / 0x1b828ca3c)
    static let pickerSpringMass: Double      = 3.0
    static let pickerSpringStiffness: Double = 1000.0
    static let pickerSpringDamping: Double   = 500.0
    static let pickerDuration: TimeInterval  = 0.5    // option-key slow-mo: 2.5

    // MARK: - Top-bar fades (`_getTopBarAnimationDuration:timeOffset:gridAnimation:`
    /// at Safari 0x1b8284744)
    static let topBarFadeConcurrent: TimeInterval = 0.16
    static let topBarFadeStandalone: TimeInterval = 0.11
    static let topBarTimeOffset:     TimeInterval = 0.18
}
