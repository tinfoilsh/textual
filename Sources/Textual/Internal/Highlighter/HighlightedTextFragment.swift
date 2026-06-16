import Foundation
import SwiftUI

// MARK: - Overview
//
// HighlightedTextFragment displays syntax-highlighted code using a two-phase approach.
//
// The first render shows a base rendering that applies only the theme's foreground color to the
// whole code string. This is cheap and never touches JavaScriptCore. When the active theme defines
// token colors and the code is within the size limit, Prism tokenization runs off the main thread
// and the colored result is published back to SwiftUI. Running tokenization synchronously inside
// `body` blocks the main thread on JavaScriptCore garbage collection, which has been observed as a
// multi-second hang on large code blocks.
//
// The presentationIntent is preserved after highlighting so pasteboard formatters can
// reconstruct the block structure when copying code.

struct HighlightedTextFragment: View {
  // Code blocks larger than this skip Prism tokenization and render with base colors only, to
  // bound JavaScriptCore work on very large inputs.
  private static let maxHighlightCharacters = 15_000

  @Environment(\.textEnvironment) private var textEnvironment

  private let content: AttributedSubstring
  private let languageHint: String?
  private let theme: StructuredText.HighlighterTheme

  @State private var cache = HighlightedCodeCache()
  @State private var highlighted: AttributedString?
  @State private var highlightedKey: HighlightedCodeCache.Key?

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
    let base = cache.value(for: key) { baseAttributedString(for: key) }
    let display = (highlightedKey == key ? highlighted : nil) ?? base

    TextFragment(display)
      .foregroundStyle(theme.foregroundColor)
      .task(id: key) {
        await updateHighlight(for: key)
      }
  }

  private func baseAttributedString(for key: HighlightedCodeCache.Key) -> AttributedString {
    Self.attributedString(
      tokens: [CodeToken(content: key.code, type: .plain)],
      presentationIntent: content.presentationIntent,
      theme: theme,
      environment: textEnvironment
    )
  }

  private func updateHighlight(for key: HighlightedCodeCache.Key) async {
    guard
      !theme.tokenProperties.isEmpty,
      let languageHint,
      key.code.count <= Self.maxHighlightCharacters,
      let tokenizer = CodeTokenizer.shared
    else {
      return
    }

    let code = key.code
    let theme = self.theme
    let environment = textEnvironment
    let presentationIntent = content.presentationIntent

    let result = await Task.detached(priority: .userInitiated) { () -> AttributedString in
      let tokens = tokenizer.tokenizeSync(code: code, language: languageHint)
      return Self.attributedString(
        tokens: tokens,
        presentationIntent: presentationIntent,
        theme: theme,
        environment: environment
      )
    }.value

    guard !Task.isCancelled else { return }

    highlighted = result
    highlightedKey = key
  }

  private nonisolated static func attributedString(
    tokens: [CodeToken],
    presentationIntent: PresentationIntent?,
    theme: StructuredText.HighlighterTheme,
    environment: TextEnvironmentValues
  ) -> AttributedString {
    var attributes = AttributeContainer()
    attributes.presentationIntent = presentationIntent
    ForegroundColorProperty(theme.foregroundColor)
      .apply(in: &attributes, environment: environment)

    var result = AttributedString()
    for token in tokens {
      var tokenContent = AttributedString(token.content)
      var tokenAttributes = attributes
      if let tokenProperties = theme.tokenProperties[token.type] {
        tokenProperties.apply(in: &tokenAttributes, environment: environment)
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
