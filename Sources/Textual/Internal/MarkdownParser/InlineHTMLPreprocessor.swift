import Foundation

// MARK: - Overview
//
// `InlineHTMLPreprocessor` converts HTML tags to their Markdown equivalents before
// Foundation's Markdown parser processes the input.
//
// Foundation's `AttributedString(markdown:)` does not support inline HTML. This preprocessor
// ensures that content containing HTML formatting (common in LLM outputs) renders correctly.
//
// Tags are handled in three tiers:
//
// 1. **Converted** — tags with direct Markdown equivalents are translated:
//    `<b>`, `<strong>`, `<i>`, `<em>`, `<code>`, `<a href>`, `<br>`,
//    `<h1>`–`<h6>`, `<p>`, `<ul>`, `<ol>`, `<li>`, `<hr>`, `<pre>`,
//    `<blockquote>`, `<del>`, `<s>`, `<strike>`.
//
// 2. **Stripped** — tags with no Markdown equivalent have their tags removed but
//    content preserved: `<span>`, `<div>`, `<sup>`, `<sub>`, `<kbd>`, `<mark>`,
//    `<abbr>`, `<details>`, `<summary>`, `<u>`, `<small>`, `<big>`, `<cite>`,
//    `<q>`, `<var>`, `<samp>`, `<dfn>`, `<ins>`, `<figure>`, `<figcaption>`,
//    `<section>`, `<article>`, `<header>`, `<footer>`, `<nav>`, `<aside>`,
//    `<main>`, `<dd>`, `<dt>`, and any tag with a `style` or `class` attribute.
//
// 3. **Passed through** — unrecognized tags are kept as literal text.
//
// The preprocessor uses a tag-aware scanner with an open-tag stack to correctly handle
// nested and interleaved tags. Code fences are detected to avoid converting HTML
// inside fenced code blocks.

extension AttributedStringMarkdownParser {
  enum InlineHTMLPreprocessor {
    private static let tagPattern = try! NSRegularExpression(
      pattern: "<\\/?([a-zA-Z0-9]+)[^>]*\\/?>",
      options: []
    )

    private static let hrefPattern = try! NSRegularExpression(
      pattern: "\\bhref\\s*=\\s*[\"']([^\"']*)[\"']",
      options: []
    )

    /// Converts HTML tags in the input to Markdown equivalents, strips tags that have
    /// no Markdown equivalent (preserving their content), and passes through anything
    /// unrecognized.
    ///
    /// Tags inside fenced code blocks are left unchanged.
    static func convert(_ input: String) -> String {
      guard input.contains("<") else { return input }

      let nsInput = input as NSString
      let matches = tagPattern.matches(
        in: input,
        range: NSRange(location: 0, length: nsInput.length)
      )

      guard !matches.isEmpty else { return input }

      var result = ""
      result.reserveCapacity(input.count)
      var cursor = input.startIndex
      var tagStack: [(tag: String, href: String?)] = []
      var insideCodeFence = false

      // Process line-by-line to detect code fences, but only for the fence
      // detection logic. Tag conversion happens character-by-character.
      for match in matches {
        guard let matchRange = Range(match.range, in: input),
              let nameRange = Range(match.range(at: 1), in: input)
        else { continue }

        let textBefore = input[cursor..<matchRange.lowerBound]

        // Check for code fence toggles in the text before this tag
        insideCodeFence = Self.updateCodeFenceState(
          insideCodeFence,
          scanning: textBefore
        )

        result += textBefore
        cursor = matchRange.upperBound

        // Inside a code fence, pass tags through literally
        if insideCodeFence {
          result += input[matchRange]
          continue
        }

        let fullTag = String(input[matchRange])
        let tagName = String(input[nameRange]).lowercased()
        let isClosing = fullTag.hasPrefix("</")
        let isSelfClosing = fullTag.hasSuffix("/>")

        switch tagName {

        // MARK: Tier 1 — Tags with Markdown equivalents

        case "br", "hr":
          if tagName == "br" {
            result += "  \n"
          } else {
            result += "\n\n---\n\n"
          }

        case "b", "strong":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "b" || $0.tag == "strong" }) {
              result += "**"
              tagStack.remove(at: index)
            } else {
              result += fullTag
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "**"
          }

        case "i", "em":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "i" || $0.tag == "em" }) {
              result += "*"
              tagStack.remove(at: index)
            } else {
              result += fullTag
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "*"
          }

        case "del", "s", "strike":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "del" || $0.tag == "s" || $0.tag == "strike" }) {
              result += "~~"
              tagStack.remove(at: index)
            } else {
              result += fullTag
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "~~"
          }

        case "code":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "code" }) {
              result += "`"
              tagStack.remove(at: index)
            } else {
              result += fullTag
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "`"
          }

        case "pre":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "pre" }) {
              result += "\n```\n"
              tagStack.remove(at: index)
            } else {
              result += fullTag
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "\n```\n"
          }

        case "a":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "a" }) {
              let href = tagStack[index].href ?? ""
              result += "](\(href))"
              tagStack.remove(at: index)
            } else {
              result += fullTag
            }
          } else if !isSelfClosing {
            let href = Self.extractHref(from: fullTag)
            tagStack.append((tag: tagName, href: href))
            result += "["
          }

        case "h1", "h2", "h3", "h4", "h5", "h6":
          let level = Int(String(tagName.last!))!
          let prefix = String(repeating: "#", count: level) + " "
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == tagName }) {
              result += "\n"
              tagStack.remove(at: index)
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "\n" + prefix
          }

        case "p":
          if isClosing || isSelfClosing {
            result += "\n\n"
          } else {
            tagStack.append((tag: tagName, href: nil))
            result += "\n\n"
          }

        case "blockquote":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "blockquote" }) {
              result += "\n"
              tagStack.remove(at: index)
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            result += "\n> "
          }

        case "ul", "ol":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "ul" || $0.tag == "ol" }) {
              result += "\n"
              tagStack.remove(at: index)
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
          }

        case "li":
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == "li" }) {
              tagStack.remove(at: index)
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
            // Determine marker based on parent list type
            let isOrdered = tagStack.contains(where: { $0.tag == "ol" })
            result += isOrdered ? "\n1. " : "\n- "
          }

        // MARK: Tier 2 — Tags stripped (content preserved)

        case "span", "div", "sup", "sub", "kbd", "mark", "abbr", "u",
             "small", "big", "cite", "q", "var", "samp", "dfn", "ins",
             "details", "summary", "figure", "figcaption",
             "section", "article", "header", "footer", "nav", "aside",
             "main", "dd", "dt", "table", "thead", "tbody", "tr", "td", "th":
          // Strip the tag, keep inner content
          if isClosing {
            if let index = tagStack.lastIndex(where: { $0.tag == tagName }) {
              tagStack.remove(at: index)
            }
          } else if !isSelfClosing {
            tagStack.append((tag: tagName, href: nil))
          }

        default:
          result += fullTag
        }
      }

      // Append remaining text after the last tag
      result += input[cursor...]

      return result
    }

    private static func extractHref(from tag: String) -> String? {
      let nsTag = tag as NSString
      guard let match = hrefPattern.firstMatch(
        in: tag,
        range: NSRange(location: 0, length: nsTag.length)
      ), let range = Range(match.range(at: 1), in: tag) else {
        return nil
      }
      return String(tag[range])
    }

    /// Scans a text fragment for code fence markers (```) and returns the updated state.
    private static func updateCodeFenceState(
      _ currentState: Bool,
      scanning text: some StringProtocol
    ) -> Bool {
      var state = currentState
      for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        if trimmed.hasPrefix("```") {
          state.toggle()
        }
      }
      return state
    }
  }
}
