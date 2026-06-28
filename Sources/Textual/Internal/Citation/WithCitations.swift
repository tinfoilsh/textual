import SwiftUI

// MARK: - Overview
//
// `WithCitations` rewrites link runs whose URL matches a configured citation into inline
// `CitationChipAttachment` attachments, while leaving the `link` attribute in place so tap handling
// is unchanged. It runs after parsing and before inline styling, so every block type and
// `InlineText` share the same treatment.

struct WithCitations<Content: View>: View {
  @Environment(\.citationConfiguration) private var configuration

  private let input: AttributedString
  private let content: (AttributedString) -> Content

  init(
    _ input: AttributedString,
    @ViewBuilder content: @escaping (AttributedString) -> Content
  ) {
    self.input = input
    self.content = content
  }

  var body: some View {
    content(resolved)
  }

  private var resolved: AttributedString {
    guard
      let configuration,
      !configuration.urls.isEmpty,
      input.containsValues(for: [\.link])
    else {
      return input
    }

    var output = input
    for run in input.runs {
      guard
        let link = run.link,
        configuration.urls.contains(link.absoluteString)
      else {
        continue
      }

      let chip = CitationChipAttachment(
        label: Self.label(for: link),
        urlString: link.absoluteString,
        style: configuration.style
      )
      output[run.range].textual.attachment = AnyAttachment(chip)
    }
    return output
  }

  // Display text for a citation chip: the source host without a leading `www.`.
  private static func label(for url: URL) -> String {
    guard let host = url.host, !host.isEmpty else {
      return url.absoluteString
    }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
  }
}
