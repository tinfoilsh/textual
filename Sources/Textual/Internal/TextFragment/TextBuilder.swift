import SwiftUI

// MARK: - Overview
//
// Builds a SwiftUI.Text from attributed content, converting attachment runs into
// placeholder images sized by each attachment's `sizeThatFits(_:in:)` result.
// Placeholders are tagged with `AttachmentAttribute` so overlays can identify and
// render the actual attachment views at the resolved layout positions.

extension Text {
  /// Creates a Text from attributed content without attachment sizing.
  init(attributedString: some AttributedStringProtocol, in environment: TextEnvironmentValues) {
    self.init(attributedString: attributedString, attachmentSizes: [:], in: environment)
  }

  fileprivate init(
    attributedString: some AttributedStringProtocol,
    attachmentSizes: [AttachmentKey: CGSize],
    in environment: TextEnvironmentValues
  ) {
    let textValues = attributedString.runs.map { run in
      var text: Text

      var runEnvironment = environment
      runEnvironment.font = run.font ?? environment.font

      let key = run.textual.attachment.map {
        AttachmentKey(attachment: $0, font: runEnvironment.font)
      }

      if let key, let size = attachmentSizes[key] {
        // Create placeholder
        text = Text(placeholderSize: size)
          .baselineOffset(key.attachment.baselineOffset(in: runEnvironment))
          .customAttribute(
            AttachmentAttribute(
              key.attachment,
              presentationIntent: run.presentationIntent
            )
          )
      } else {
        text = Text(AttributedString(attributedString[run.range]))
      }

      // Add link attribute for TextLinkInteraction
      if let link = run.link {
        text = text.customAttribute(LinkAttribute(link))
      }

      return text
    }

    self = Self.combined(textValues[...])
  }

  private init(placeholderSize size: CGSize) {
    self.init(SwiftUI.Image(size: size) { _ in })
  }

  private static func combined(_ textValues: ArraySlice<Text>) -> Text {
    switch textValues.count {
    case 0:
      return Text(verbatim: "")
    case 1:
      return textValues[textValues.startIndex]
    default:
      let midpoint = textValues.index(
        textValues.startIndex,
        offsetBy: textValues.count / 2
      )
      return combined(textValues[..<midpoint]) + combined(textValues[midpoint...])
    }
  }
}

extension AttributedStringProtocol {
  fileprivate func attachmentSizes(
    for proposal: ProposedViewSize, in environment: TextEnvironmentValues
  ) -> [AttachmentKey: CGSize] {
    Dictionary(
      self.runs.compactMap { run in
        guard let attachment = run.textual.attachment else {
          return nil
        }
        var environment = environment
        environment.font = run.font ?? environment.font
        return (
          AttachmentKey(
            attachment: attachment,
            font: environment.font
          ),
          attachment.sizeThatFits(proposal, in: environment)
        )
      },
      uniquingKeysWith: { existing, _ in existing }
    )
  }
}

private struct AttachmentKey: Hashable {
  let attachment: AnyAttachment
  let font: Font?
}
