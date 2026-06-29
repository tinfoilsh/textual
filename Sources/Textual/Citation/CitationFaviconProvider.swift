import SwiftUI

/// Asynchronously provides favicon image data for a citation's URL.
///
/// Return the raw encoded bytes of the favicon (for example PNG or ICO) for the given page URL, or
/// `nil` if no favicon is available. Set a provider with
/// ``TextualNamespace/citationFaviconProvider(_:)`` to show source favicons on citation chips;
/// without one, chips render their fallback icon.
///
/// Textual never fetches favicons on its own, so the provider is the only network path. This lets
/// the host application route favicon loading through its own infrastructure.
public typealias CitationFaviconProvider = @Sendable (URL) async -> Data?

extension EnvironmentValues {
  @Entry var citationFaviconProvider: CitationFaviconProvider? = nil
}
