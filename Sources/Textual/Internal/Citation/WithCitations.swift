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
    content(CitationResolver.resolve(input, configuration: configuration))
  }
}

// Rewrites link runs whose URL matches a configured citation into inline citation chip
// attachments. Extracted from the view so the matching logic can be unit tested.
enum CitationResolver {
  static func resolve(
    _ input: AttributedString,
    configuration: CitationConfiguration?
  ) -> AttributedString {
    guard
      let configuration,
      !configuration.urls.isEmpty,
      input.containsValues(for: [\.link])
    else {
      return input
    }

    let normalizedURLs = Set(configuration.urls.map(normalize))

    var output = input
    for run in input.runs {
      guard
        let link = run.link,
        normalizedURLs.contains(normalize(link.absoluteString))
      else {
        continue
      }

      let chip = CitationChipAttachment(
        label: label(for: link),
        urlString: link.absoluteString,
        style: configuration.style
      )
      output[run.range].textual.attachment = AnyAttachment(chip)
    }
    return output
  }

  // Normalizes a URL string so citations match despite trivial differences (scheme, trailing
  // slash, or a leading `www.`).
  static func normalize(_ urlString: String) -> String {
    var value = urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    for scheme in ["https://", "http://"] where value.hasPrefix(scheme) {
      value.removeFirst(scheme.count)
      break
    }
    if value.hasPrefix("www.") {
      value.removeFirst(4)
    }
    while value.hasSuffix("/") {
      value.removeLast()
    }
    return value
  }

  // Display text for a citation chip: the source host without a leading `www.`.
  static func label(for url: URL) -> String {
    guard let host = url.host, !host.isEmpty else {
      return url.absoluteString
    }
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
  }
}
