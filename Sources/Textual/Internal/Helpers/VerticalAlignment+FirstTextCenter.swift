import SwiftUI

extension VerticalAlignment {
  private enum FirstTextCenterAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      // Anchor on the first text baseline. This is immune to asymmetric padding
      // (e.g. block spacing with only top or only bottom padding) that would skew
      // a height-based center calculation.
      //
      // Both the marker and block content use the same font, so their baselines
      // sit at the same relative position within the text line. Aligning on the
      // baseline ensures the marker and first line of content always match,
      // regardless of any surrounding padding or line spacing.
      context[.firstTextBaseline]
    }
  }

  static let firstTextCenter = Self(FirstTextCenterAlignment.self)
}
