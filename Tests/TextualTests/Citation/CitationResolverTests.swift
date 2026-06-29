import Foundation
import Testing

@testable import Textual

@MainActor
struct CitationResolverTests {
  private func parse(_ markdown: String) throws -> AttributedString {
    try AttributedStringMarkdownParser.markdown().attributedString(for: markdown)
  }

  private func attachmentCount(_ attributedString: AttributedString) -> Int {
    attributedString.runs.reduce(into: 0) { count, run in
      if run.textual.attachment != nil { count += 1 }
    }
  }

  @Test func rewritesExactMatch() throws {
    let input = try parse("See [GlobalMeteo](https://globalmeteo.com).")
    let config = CitationConfiguration(urls: ["https://globalmeteo.com"], style: .default)
    let output = CitationResolver.resolve(input, configuration: config)
    #expect(attachmentCount(output) == 1)
  }

  @Test func rewritesDespiteTrailingSlashAndWWW() throws {
    let input = try parse("See [NBC](https://www.nbcboston.com/weather).")
    let config = CitationConfiguration(urls: ["https://nbcboston.com/weather/"], style: .default)
    let output = CitationResolver.resolve(input, configuration: config)
    #expect(attachmentCount(output) == 1)
  }

  @Test func leavesNonCitationLinks() throws {
    let input = try parse("See [Other](https://example.com).")
    let config = CitationConfiguration(urls: ["https://globalmeteo.com"], style: .default)
    let output = CitationResolver.resolve(input, configuration: config)
    #expect(attachmentCount(output) == 0)
  }

  @Test func reportsParsedLinkValue() throws {
    let input = try parse("See [NBC](https://www.nbcboston.com/weather).")
    let link = input.runs.compactMap(\.link).first
    #expect(link?.absoluteString == "https://www.nbcboston.com/weather")
  }
}
