import SwiftUI

// MARK: - Overview
//
// HighlightedTextFragment displays syntax-highlighted code using a two-phase approach.
// Tokenization runs asynchronously and is keyed by content, while highlighting runs
// synchronously on token or environment changes (theme, color scheme, dynamic type).
//
// The presentationIntent is preserved after highlighting so pasteboard formatters can
// reconstruct the block structure when copying code.

struct HighlightedTextFragment: View {
  @Environment(\.textEnvironment) private var textEnvironment

  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  @State private var cache = HighlightedCodeCache()

  init(
    _ content: AttributedSubstring,
    languageHint: String?,
    theme: StructuredText.HighlighterTheme
  ) {
    self.content = content
    self.languageHint = languageHint
    self.theme = theme
  }

  var body: some View {
    let key = HighlightedCodeCache.Key(
      code: String(content.characters[...]),
      languageHint: languageHint,
      theme: theme,
      environment: textEnvironment
    )
    TextFragment(cache.value(for: key) { highlightedCode })
      .foregroundStyle(theme.foregroundColor)
  }

  private var highlightedCode: AttributedString {
    let code = String(content.characters[...])

    let tokens: [CodeToken]
    if let tokenizer = CodeTokenizer.shared, let languageHint {
      tokens = tokenizer.tokenizeSync(code: code, language: languageHint)
    } else {
      tokens = [CodeToken(content: code, type: .plain)]
    }

    var attributes = AttributeContainer()
    attributes.presentationIntent = content.presentationIntent
    ForegroundColorProperty(theme.foregroundColor)
      .apply(in: &attributes, environment: textEnvironment)

    var result = AttributedString()
    for token in tokens {
      var tokenContent = AttributedString(token.content)
      var tokenAttributes = attributes
      if let tokenProperties = theme.tokenProperties[token.type] {
        tokenProperties.apply(in: &tokenAttributes, environment: textEnvironment)
      }
      tokenContent.mergeAttributes(tokenAttributes)
      result.append(tokenContent)
    }
    return result
  }
}

// Per-instance cache that retains the last-produced `AttributedString` keyed
// by code + language + theme + environment. Tokenization and attribute merging
// are expensive; without this cache they re-run on every view update, which
// together with Text's CoreText shaping becomes a measurable hang.
@MainActor
final class HighlightedCodeCache {
  struct Key: Hashable {
    let code: String
    let languageHint: String?
    let theme: StructuredText.HighlighterTheme
    let environment: TextEnvironmentValues
  }

  private var cachedKey: Key?
  private var cachedValue: AttributedString?

  func value(for key: Key, build: () -> AttributedString) -> AttributedString {
    if let cachedValue, cachedKey == key {
      return cachedValue
    }
    let value = build()
    cachedKey = key
    cachedValue = value
    return value
  }
}
