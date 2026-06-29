import SwiftUI

/// The font weight used for a citation chip's label.
public enum CitationFontWeight: Sendable, Hashable {
  case regular
  case medium
  case semibold
  case bold
}

/// Customizes the appearance of inline citation chips rendered by ``InlineText`` and
/// ``StructuredText``.
///
/// Citation chips replace the inline link of a URL marked as a citation with a compact pill
/// showing the source domain and an icon, making citations visually distinct from regular links.
/// Mark links as citations with ``TextualNamespace/citations(_:style:)``.
public struct CitationStyle: Sendable, Hashable {
  /// The color of the chip's label text.
  public var foregroundColor: Color
  /// The color of the chip's rounded background.
  public var backgroundColor: Color
  /// The color of the chip's leading icon.
  public var iconColor: Color
  /// The SF Symbol name for the chip's leading icon.
  public var iconSystemName: String
  /// The chip label's font size relative to the surrounding body font.
  public var fontScale: CGFloat
  /// The chip label's font weight.
  public var fontWeight: CitationFontWeight
  /// Horizontal padding inside the chip.
  public var horizontalPadding: CGFloat
  /// Vertical padding inside the chip.
  public var verticalPadding: CGFloat
  /// Spacing between the chip's icon and label.
  public var iconSpacing: CGFloat
  /// Whether the chip shows the source's favicon, falling back to the icon when unavailable.
  ///
  /// Favicons load through the provider set with ``TextualNamespace/citationFaviconProvider(_:)``;
  /// with no provider the chip always shows the icon.
  public var showsFavicon: Bool

  public init(
    foregroundColor: Color,
    backgroundColor: Color,
    iconColor: Color,
    iconSystemName: String,
    fontScale: CGFloat,
    fontWeight: CitationFontWeight,
    horizontalPadding: CGFloat,
    verticalPadding: CGFloat,
    iconSpacing: CGFloat,
    showsFavicon: Bool = true
  ) {
    self.foregroundColor = foregroundColor
    self.backgroundColor = backgroundColor
    self.iconColor = iconColor
    self.iconSystemName = iconSystemName
    self.fontScale = fontScale
    self.fontWeight = fontWeight
    self.horizontalPadding = horizontalPadding
    self.verticalPadding = verticalPadding
    self.iconSpacing = iconSpacing
    self.showsFavicon = showsFavicon
  }

  /// A default citation chip style: an accent-tinted pill with a globe icon and the source domain.
  public static let `default` = CitationStyle(
    foregroundColor: .accentColor,
    backgroundColor: Color.accentColor.opacity(0.12),
    iconColor: .accentColor,
    iconSystemName: "globe",
    fontScale: 0.85,
    fontWeight: .medium,
    horizontalPadding: 6,
    verticalPadding: 2,
    iconSpacing: 3
  )
}

extension CitationFontWeight {
  var swiftUIWeight: Font.Weight {
    switch self {
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    }
  }
}
