import Foundation

/// A ``MarkupParser`` implementation backed by Foundation’s Markdown support.
///
/// This parser leverages Foundation’s Markdown support and preserves structure via
/// presentation intents.
///
/// This parser can process its output to expand custom emoji and math expressions into
/// inline attachments.
public struct AttributedStringMarkdownParser: MarkupParser {
  private let baseURL: URL?
  private let options: AttributedString.MarkdownParsingOptions
  private let processor: PatternProcessor
  private let cacheConfiguration: CacheConfiguration

  @MainActor
  private static let cache: NSCache<KeyBox<CacheKey>, Box<AttributedString>> = {
    let cache = NSCache<KeyBox<CacheKey>, Box<AttributedString>>()
    cache.countLimit = 128
    return cache
  }()

  public init(
    baseURL: URL?,
    options: AttributedString.MarkdownParsingOptions = .init(),
    syntaxExtensions: [SyntaxExtension] = []
  ) {
    self.baseURL = baseURL
    self.options = options
    self.processor = PatternProcessor(syntaxExtensions: syntaxExtensions)
    self.cacheConfiguration = CacheConfiguration(
      baseURL: baseURL?.absoluteString,
      optionsDescription: String(reflecting: options),
      syntaxExtensionCacheKeys: syntaxExtensions.map(\.cacheIdentity)
    )
  }

  public func attributedString(for input: String) throws -> AttributedString {
    let cacheKey = CacheKey(input: input, configuration: cacheConfiguration)
    if let cached = Self.cache.object(forKey: KeyBox(cacheKey)) {
      return cached.wrappedValue
    }

    let preprocessed = InlineHTMLPreprocessor.convert(input)
    let attributedString = try processor.expand(
      AttributedString(
        markdown: preprocessed,
        including: \.textual,
        options: options,
        baseURL: baseURL
      )
    )
    Self.cache.setObject(Box(attributedString), forKey: KeyBox(cacheKey))
    return attributedString
  }
}

extension AttributedStringMarkdownParser {
  private struct CacheConfiguration: Hashable {
    let baseURL: String?
    let optionsDescription: String
    let syntaxExtensionCacheKeys: [AnyHashable]
  }

  private struct CacheKey: Hashable {
    let input: String
    let configuration: CacheConfiguration
  }
}

extension MarkupParser where Self == AttributedStringMarkdownParser {
  /// Creates a Markdown parser configured for inline-only syntax.
  public static func inlineMarkdown(
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) -> Self {
    .init(
      baseURL: baseURL,
      options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace),
      syntaxExtensions: syntaxExtensions
    )
  }

  /// Creates a Markdown parser configured for full-document syntax.
  public static func markdown(
    baseURL: URL? = nil,
    syntaxExtensions: [AttributedStringMarkdownParser.SyntaxExtension] = []
  ) -> Self {
    .init(
      baseURL: baseURL,
      syntaxExtensions: syntaxExtensions
    )
  }
}
