import SwiftUI

// Holds the set of URLs to render as citation chips along with their style. Provided through the
// environment by `TextualNamespace.citations(_:style:)` and consumed by `WithCitations`.
struct CitationConfiguration: Hashable, Sendable {
  var urls: Set<String>
  var style: CitationStyle
}

extension EnvironmentValues {
  @Entry var citationConfiguration: CitationConfiguration? = nil
}
