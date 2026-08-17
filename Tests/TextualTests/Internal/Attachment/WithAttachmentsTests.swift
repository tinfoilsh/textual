import SwiftUI
import Testing

@testable import Textual

struct WithAttachmentsTests {
  @Test @MainActor
  func resolvedAttachmentRemainsAssociatedWithItsSource() {
    let source = AttributedString("x")
    let model = WithAttachments<EmptyView>.Model()
    model.resolveAttachmentsFinished(
      attributedString: source,
      attachments: [
        (source.startIndex..<source.endIndex, AnyAttachment(TestAttachment()))
      ]
    )

    let displayed = model.displayedAttributedString(for: source)

    #expect(displayed.runs.first?.textual.attachment != nil)
  }
}

private struct TestAttachment: Textual.Attachment {
  let description = "test"

  var body: some View {
    EmptyView()
  }

  func sizeThatFits(
    _: ProposedViewSize,
    in _: TextEnvironmentValues
  ) -> CGSize {
    .zero
  }
}
