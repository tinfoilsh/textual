import SwiftUI

// Caches favicons resolved through a `CitationFaviconProvider`. Lookups are synchronous so the chip
// view can read a cached favicon while rendering; a miss starts a one-time fetch through the
// provider and publishes a change once the favicon is decoded, prompting the chip to redraw with
// the favicon in place of its fallback icon.
//
// Keyed by the citation's URL string to match how the provider is queried. Failures and in-flight
// requests are tracked so a missing or slow favicon is only attempted once.
@MainActor
final class CitationFaviconStore: ObservableObject {
  static let shared = CitationFaviconStore()

  private var cache: [String: CGImage] = [:]
  private var failedKeys: Set<String> = []
  private var inFlightKeys: Set<String> = []

  private init() {}

  func favicon(for key: String) -> CGImage? {
    cache[key]
  }

  func loadIfNeeded(url: URL, provider: @escaping CitationFaviconProvider) {
    let key = url.absoluteString
    guard
      cache[key] == nil,
      !failedKeys.contains(key),
      !inFlightKeys.contains(key)
    else {
      return
    }

    inFlightKeys.insert(key)
    Task {
      defer { inFlightKeys.remove(key) }
      guard
        let data = await provider(url),
        let image = Image(data: data)
      else {
        failedKeys.insert(key)
        return
      }
      objectWillChange.send()
      cache[key] = image.cgImage
    }
  }
}
