import Foundation
import Testing

@testable import Textual

extension AttributedStringMarkdownParser {
  struct InlineHTMLPreprocessorTests {
    // MARK: - Passthrough

    @Test func plainTextPassthrough() {
      let input = "Hello, world!"
      #expect(InlineHTMLPreprocessor.convert(input) == input)
    }

    @Test func emptyInput() {
      #expect(InlineHTMLPreprocessor.convert("") == "")
    }

    @Test func angleBracketWithoutTag() {
      let input = "a < b and c > d"
      #expect(InlineHTMLPreprocessor.convert(input) == input)
    }

    @Test func markdownWithoutHTML() {
      let input = "**bold** and *italic* and `code`"
      #expect(InlineHTMLPreprocessor.convert(input) == input)
    }

    // MARK: - Tier 1: Bold

    @Test func boldTag() {
      #expect(InlineHTMLPreprocessor.convert("<b>text</b>") == "**text**")
    }

    @Test func strongTag() {
      #expect(InlineHTMLPreprocessor.convert("<strong>text</strong>") == "**text**")
    }

    // MARK: - Tier 1: Italic

    @Test func italicTag() {
      #expect(InlineHTMLPreprocessor.convert("<i>text</i>") == "*text*")
    }

    @Test func emTag() {
      #expect(InlineHTMLPreprocessor.convert("<em>text</em>") == "*text*")
    }

    // MARK: - Tier 1: Strikethrough

    @Test func delTag() {
      #expect(InlineHTMLPreprocessor.convert("<del>text</del>") == "~~text~~")
    }

    @Test func sTag() {
      #expect(InlineHTMLPreprocessor.convert("<s>text</s>") == "~~text~~")
    }

    @Test func strikeTag() {
      #expect(InlineHTMLPreprocessor.convert("<strike>text</strike>") == "~~text~~")
    }

    // MARK: - Tier 1: Code

    @Test func codeTag() {
      #expect(InlineHTMLPreprocessor.convert("<code>text</code>") == "`text`")
    }

    @Test func preTag() {
      #expect(InlineHTMLPreprocessor.convert("<pre>code here</pre>") == "\n```\ncode here\n```\n")
    }

    // MARK: - Tier 1: Line Break & Horizontal Rule

    @Test func brTag() {
      #expect(InlineHTMLPreprocessor.convert("line1<br>line2") == "line1  \nline2")
    }

    @Test func selfClosingBrTag() {
      #expect(InlineHTMLPreprocessor.convert("line1<br/>line2") == "line1  \nline2")
    }

    @Test func brWithSpace() {
      #expect(InlineHTMLPreprocessor.convert("line1<br />line2") == "line1  \nline2")
    }

    @Test func hrTag() {
      #expect(InlineHTMLPreprocessor.convert("above<hr>below") == "above\n\n---\n\nbelow")
    }

    // MARK: - Tier 1: Links

    @Test func anchorTagWithDoubleQuotes() {
      let input = #"<a href="https://example.com">click here</a>"#
      #expect(InlineHTMLPreprocessor.convert(input) == "[click here](https://example.com)")
    }

    @Test func anchorTagWithSingleQuotes() {
      let input = "<a href='https://example.com'>click here</a>"
      #expect(InlineHTMLPreprocessor.convert(input) == "[click here](https://example.com)")
    }

    @Test func anchorTagWithExtraAttributes() {
      let input = #"<a class="link" href="https://example.com" target="_blank">click</a>"#
      #expect(InlineHTMLPreprocessor.convert(input) == "[click](https://example.com)")
    }

    @Test func anchorTagWithoutHref() {
      let input = "<a>text</a>"
      #expect(InlineHTMLPreprocessor.convert(input) == "[text]()")
    }

    // MARK: - Tier 1: Headings

    @Test func h1Tag() {
      #expect(InlineHTMLPreprocessor.convert("<h1>Title</h1>") == "\n# Title\n")
    }

    @Test func h3Tag() {
      #expect(InlineHTMLPreprocessor.convert("<h3>Section</h3>") == "\n### Section\n")
    }

    // MARK: - Tier 1: Paragraphs

    @Test func pTag() {
      #expect(InlineHTMLPreprocessor.convert("<p>First</p><p>Second</p>") == "\n\nFirst\n\n\n\nSecond\n\n")
    }

    // MARK: - Tier 1: Lists

    @Test func unorderedList() {
      let input = "<ul><li>one</li><li>two</li></ul>"
      let result = InlineHTMLPreprocessor.convert(input)
      #expect(result.contains("- one"))
      #expect(result.contains("- two"))
    }

    @Test func orderedList() {
      let input = "<ol><li>first</li><li>second</li></ol>"
      let result = InlineHTMLPreprocessor.convert(input)
      #expect(result.contains("1. first"))
      #expect(result.contains("1. second"))
    }

    // MARK: - Tier 1: Blockquote

    @Test func blockquoteTag() {
      let input = "<blockquote>quoted text</blockquote>"
      let result = InlineHTMLPreprocessor.convert(input)
      #expect(result.contains("> quoted text"))
    }

    // MARK: - Tier 1: Nesting

    @Test func boldInsideItalic() {
      let input = "<i><b>text</b></i>"
      #expect(InlineHTMLPreprocessor.convert(input) == "***text***")
    }

    @Test func italicInsideBold() {
      let input = "<b><i>text</i></b>"
      #expect(InlineHTMLPreprocessor.convert(input) == "***text***")
    }

    @Test func boldInsideLink() {
      let input = #"<a href="https://example.com"><b>bold link</b></a>"#
      #expect(InlineHTMLPreprocessor.convert(input) == "[**bold link**](https://example.com)")
    }

    // MARK: - Tier 1: Mixed Content

    @Test func htmlMixedWithMarkdown() {
      let input = "**bold** and <i>italic</i> together"
      #expect(InlineHTMLPreprocessor.convert(input) == "**bold** and *italic* together")
    }

    @Test func multipleTagsInSequence() {
      let input = "<b>bold</b> then <i>italic</i> then <code>code</code>"
      #expect(InlineHTMLPreprocessor.convert(input) == "**bold** then *italic* then `code`")
    }

    // MARK: - Tier 2: Stripped Tags (content preserved)

    @Test func supTagStripped() {
      #expect(InlineHTMLPreprocessor.convert("x<sup>2</sup>") == "x2")
    }

    @Test func subTagStripped() {
      #expect(InlineHTMLPreprocessor.convert("H<sub>2</sub>O") == "H2O")
    }

    @Test func kbdTagStripped() {
      #expect(InlineHTMLPreprocessor.convert("Press <kbd>Ctrl</kbd>") == "Press Ctrl")
    }

    @Test func markTagStripped() {
      #expect(InlineHTMLPreprocessor.convert("<mark>highlighted</mark>") == "highlighted")
    }

    @Test func spanTagStripped() {
      #expect(InlineHTMLPreprocessor.convert("<span class=\"red\">text</span>") == "text")
    }

    @Test func divTagStripped() {
      #expect(InlineHTMLPreprocessor.convert("<div>text</div>") == "text")
    }

    @Test func detailsSummaryStripped() {
      let input = "<details><summary>Title</summary>content</details>"
      #expect(InlineHTMLPreprocessor.convert(input) == "Titlecontent")
    }

    @Test func nestedStrippedTags() {
      let input = "<div><span>inner</span></div>"
      #expect(InlineHTMLPreprocessor.convert(input) == "inner")
    }

    @Test func tableTagsStripped() {
      let input = "<table><tr><td>cell</td></tr></table>"
      #expect(InlineHTMLPreprocessor.convert(input) == "cell")
    }

    // MARK: - Edge Cases

    @Test func unclosedBoldTag() {
      let input = "<b>unclosed"
      #expect(InlineHTMLPreprocessor.convert(input) == "**unclosed")
    }

    @Test func closingTagWithoutOpening() {
      let input = "text</b>"
      #expect(InlineHTMLPreprocessor.convert(input) == "text</b>")
    }

    @Test func caseInsensitiveTags() {
      #expect(InlineHTMLPreprocessor.convert("<B>text</B>") == "**text**")
    }

    @Test func unrecognizedTagPassthrough() {
      let input = "<custom-element>text</custom-element>"
      #expect(InlineHTMLPreprocessor.convert(input) == "<custom-element>text</custom-element>")
    }

    // MARK: - Code Fence Awareness

    @Test func htmlInsideCodeFenceLeftAlone() {
      let input = """
        ```html
        <b>bold</b>
        ```
        """
      #expect(InlineHTMLPreprocessor.convert(input) == input)
    }

    @Test func htmlOutsideCodeFenceConverted() {
      let input = """
        <b>bold</b>
        ```
        <i>literal</i>
        ```
        <i>italic</i>
        """
      let expected = """
        **bold**
        ```
        <i>literal</i>
        ```
        *italic*
        """
      #expect(InlineHTMLPreprocessor.convert(input) == expected)
    }
  }
}
