import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

// An inline attachment that renders a citation as a compact pill (icon + source domain). The
// surrounding run keeps its `link` attribute, so tapping the chip opens the URL exactly like a
// regular link.
struct CitationChipAttachment: Attachment {
  let label: String
  let urlString: String
  let style: CitationStyle

  var description: String {
    "[\(label)](\(urlString))"
  }

  var selectionStyle: AttachmentSelectionStyle {
    .text
  }

  var body: some View {
    CitationChipView(label: label, style: style)
  }

  func baselineOffset(in environment: TextEnvironmentValues) -> CGFloat {
    CitationChipMetrics.resolve(label: label, style: style, in: environment).baselineOffset
  }

  func sizeThatFits(_: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
    CitationChipMetrics.resolve(label: label, style: style, in: environment).size
  }
}

// Resolves chip geometry from the surrounding text environment. Both the attachment's sizing and
// the rendered view read these metrics so the placeholder reserved in the text layout matches the
// drawn chip exactly.
struct CitationChipMetrics {
  let fontSize: CGFloat
  let iconSize: CGFloat
  let iconSpacing: CGFloat
  let horizontalPadding: CGFloat
  let verticalPadding: CGFloat
  let size: CGSize
  let baselineOffset: CGFloat

  static func resolve(
    label: String,
    style: CitationStyle,
    in environment: TextEnvironmentValues
  ) -> CitationChipMetrics {
    let bodyDescriptor = FontDescriptor.preferredFontDescriptor(withTextStyle: .body, in: environment)
    let bodyPointSize = bodyDescriptor.pointSize
    let bodyFont = PlatformFont.systemFont(ofSize: bodyPointSize)

    let fontSize = max(1, (bodyPointSize * style.fontScale).rounded())
    let chipFont = PlatformFont.systemFont(ofSize: fontSize, weight: style.fontWeight.platformWeight)
    let iconSize = fontSize

    let labelWidth = (label as NSString)
      .size(withAttributes: [.font: chipFont])
      .width
    let contentWidth = iconSize + style.iconSpacing + labelWidth
    let width = (contentWidth + style.horizontalPadding * 2).rounded(.up)

    let textHeight = chipFont.ascender - chipFont.descender
    let height = (max(iconSize, textHeight) + style.verticalPadding * 2).rounded(.up)
    let size = CGSize(width: width, height: height)

    // Center the chip vertically on the surrounding text's cap height. A placeholder image sits on
    // the baseline by default, so a negative offset lowers the chip until its center aligns with the
    // middle of the cap-height band.
    let baselineOffset = -((height - bodyFont.capHeight) / 2)

    return CitationChipMetrics(
      fontSize: fontSize,
      iconSize: iconSize,
      iconSpacing: style.iconSpacing,
      horizontalPadding: style.horizontalPadding,
      verticalPadding: style.verticalPadding,
      size: size,
      baselineOffset: baselineOffset
    )
  }
}

private struct CitationChipView: View {
  @Environment(\.textEnvironment) private var environment
  let label: String
  let style: CitationStyle

  var body: some View {
    let metrics = CitationChipMetrics.resolve(label: label, style: style, in: environment)
    HStack(spacing: metrics.iconSpacing) {
      SwiftUI.Image(systemName: style.iconSystemName)
        .font(.system(size: metrics.iconSize * 0.9, weight: .semibold))
        .frame(width: metrics.iconSize, height: metrics.iconSize)
        .foregroundStyle(style.iconColor)
      Text(label)
        .font(.system(size: metrics.fontSize, weight: style.fontWeight.swiftUIWeight))
        .foregroundStyle(style.foregroundColor)
        .lineLimit(1)
        .fixedSize()
    }
    .padding(.horizontal, metrics.horizontalPadding)
    .padding(.vertical, metrics.verticalPadding)
    .frame(width: metrics.size.width, height: metrics.size.height)
    .background(Capsule().fill(style.backgroundColor))
  }
}

extension CitationFontWeight {
  var platformWeight: PlatformFont.Weight {
    switch self {
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    }
  }
}
