import SwiftUI

// MARK: - Overview
//
// TextFragment renders attributed content as SwiftUI.Text with support for inline
// attachments, links, and selection. It uses a TextBuilder to construct and cache
// Text values, minimizing rebuilds during resize by keying on attachment sizes.
//
// Attachments are represented as placeholder images tagged with AttachmentAttribute. The
// actual attachment views are rendered in an overlay using the resolved Text.Layout
// geometry. Three modifiers are applied at the fragment level:
//
// - TextSelectionBackground renders selection highlights on macOS
// - AttachmentOverlay draws attachments at their run locations with selection-aware dimming
// - TextLinkInteraction handles tap gestures on links
//
// These overlays use backgroundPreferenceValue and overlayPreferenceValue to access
// Text.Layout and render in fragment-local coordinates. Fragment-level overlays enable
// coordinate space isolation and keep scrollable regions interactive.
//
// An ancestor view must define a named coordinate space (.textContainer) for the text
// container. TextFragment uses onGeometryChange to observe the container size and rebuild
// Text when attachment sizes need to change.
//
// TextFragment is used by InlineText and StructuredText (via BlockContent) to render
// attributed content with inline attachments, links, and selection.

struct TextFragment: View {
  @Environment(\.textEnvironment) private var textEnvironment
  #if TEXTUAL_ENABLE_TEXT_SELECTION
    @Environment(\.textSelection) private var textSelection
  #endif

  private let content: AttributedString

  init(_ content: AttributedString) {
    self.content = content
  }

  var body: some View {
    CachedTextFragment(
      content: content,
      attachments: content.attachments(),
      hasLinks: installsLinkInteraction,
      environment: textEnvironment
    )
  }

  private var installsLinkInteraction: Bool {
    guard content.containsValues(for: [\.link]) else {
      return false
    }

    #if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
      if textSelection.allowsSelection {
        return false
      }
    #endif

    return true
  }
}

// Holds the rendered `Text` in a @State-backed store so SwiftUI re-uses the
// same `Text` value across view updates. `Text(attributedString:)` maintains
// an internal metrics cache that is dropped when the instance is recreated;
// keeping the same instance avoids repeated CoreText shaping during layout
// passes.
private struct CachedTextFragment: View {
  let content: AttributedString
  let attachments: Set<AnyAttachment>
  let hasLinks: Bool
  let environment: TextEnvironmentValues

  @State private var store = TextStore()

  var body: some View {
    let text = store.text(for: content, environment: environment)

    return text
      .customAttribute(TextFragmentAttribute())
      .modifier(TextSelectionBackground())
      .modifier(AttachmentOverlay(attachments: attachments))
      .modifier(TextLinkInteraction(hasLinks: hasLinks))
  }
}

@MainActor
private final class TextStore {
  private var cachedText: Text?
  private var cachedContent: AttributedString?
  private var cachedEnvironment: TextEnvironmentValues?

  func text(
    for content: AttributedString,
    environment: TextEnvironmentValues
  ) -> Text {
    if let cachedText,
       cachedContent == content,
       cachedEnvironment == environment {
      return cachedText
    }

    let text = Text(attributedString: content, reservingWidthIn: environment)
    cachedText = text
    cachedContent = content
    cachedEnvironment = environment
    return text
  }
}

struct TextFragmentAttribute: TextAttribute {
}

extension Text.Layout {
  var isTextFragment: Bool {
    first?.first?[TextFragmentAttribute.self] != nil
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  static var textContainer: NamedCoordinateSpace {
    .named("textContainer")
  }
}

extension GeometryProxy {
  fileprivate var textContainerSize: CGSize? {
    bounds(of: .textContainer)?.size
  }
}
