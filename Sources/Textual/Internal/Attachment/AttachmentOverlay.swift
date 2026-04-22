import SwiftUI

// MARK: - Overview
//
// `AttachmentOverlay` renders attachment views using resolved `Text.Layout` geometry.
//
// It’s applied at the text fragment level. The fragment exposes the resolved layout through the
// `Text.LayoutKey` preference; this modifier reads the anchored layout, converts its anchor to a
// concrete origin using `GeometryReader`, and installs an `AttachmentView` that draws attachments
// at their run bounds.

struct AttachmentOverlay: ViewModifier {
  private let attachments: Set<AnyAttachment>

  init(attachments: Set<AnyAttachment>) {
    self.attachments = attachments
  }

  func body(content: Content) -> some View {
    // Installing overlayPreferenceValue forces SwiftUI to read Text.LayoutKey
    // for every text fragment, which synchronously resolves line fragments via
    // CoreText on the main thread. Skip it entirely when the fragment has no
    // attachments to render.
    if attachments.isEmpty {
      content
    } else {
      content
        .overlayPreferenceValue(Text.LayoutKey.self) { value in
          if let anchoredLayout = value.first {
            GeometryReader { geometry in
              AttachmentView(
                attachments: attachments,
                origin: geometry[anchoredLayout.origin],
                layout: anchoredLayout.layout
              )
            }
          }
        }
    }
  }
}
