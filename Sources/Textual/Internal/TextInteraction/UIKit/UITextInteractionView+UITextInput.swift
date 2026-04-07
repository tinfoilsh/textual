#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI

  extension UITextInteractionView: UITextInput {
    var hasText: Bool {
      model.hasText
    }

    func insertText(_: String) {
      // Do nothing
    }

    func deleteBackward() {
      // Do nothing
    }

    func text(in range: UITextRange) -> String? {
      guard let rangeBox = range as? TextRangeBox else { return nil }
      return model.text(in: rangeBox.wrappedValue)
    }

    func replace(_ range: UITextRange, withText text: String) {
      // Do nothing
    }

    var selectedTextRange: UITextRange? {
      get { model.selectedRange.map(TextRangeBox.init) }
      set {
        let rangeBox = newValue as? TextRangeBox
        guard model.selectedRange != rangeBox?.wrappedValue else { return }
        model.selectedRange = rangeBox?.wrappedValue
        logger.debug("selectedTextRange = \(newValue)")
      }
    }

    var markedTextRange: UITextRange? {
      nil
    }

    var markedTextStyle: [NSAttributedString.Key: Any]? {
      get { nil }
      set {}
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
      // Do nothing
    }

    func unmarkText() {
      // Do nothing
    }

    var beginningOfDocument: UITextPosition {
      TextPositionBox(model.startPosition)
    }

    var endOfDocument: UITextPosition {
      TextPositionBox(model.endPosition)
    }

    func textRange(
      from fromPosition: UITextPosition,
      to toPosition: UITextPosition
    ) -> UITextRange? {
      guard
        let from = fromPosition as? TextPositionBox,
        let to = toPosition as? TextPositionBox
      else {
        return nil
      }
      return TextRangeBox(from: from, to: to)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
      guard let positionBox = position as? TextPositionBox else { return nil }
      return model.position(
        from: positionBox.wrappedValue,
        offset: offset
      ).map(TextPositionBox.init)
    }

    func position(
      from position: UITextPosition,
      in direction: UITextLayoutDirection,
      offset: Int
    ) -> UITextPosition? {
      guard let positionBox = position as? TextPositionBox else { return nil }
      guard offset != 0 else { return position }

      var currentPosition = positionBox.wrappedValue
      let direction = offset > 0 ? direction : direction.reversed

      for _ in 0..<abs(offset) {
        guard let nextPosition = adjacentPosition(from: currentPosition, in: direction) else {
          return nil
        }
        currentPosition = nextPosition
      }

      return TextPositionBox(currentPosition)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
      guard
        let lhs = position as? TextPositionBox, let rhs = other as? TextPositionBox,
        lhs.wrappedValue != rhs.wrappedValue
      else {
        return .orderedSame
      }
      return lhs.wrappedValue < rhs.wrappedValue ? .orderedAscending : .orderedDescending
    }

    func offset(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> Int {
      guard
        let from = fromPosition as? TextPositionBox,
        let to = toPosition as? TextPositionBox
      else { return 0 }
      return model.offset(from: from.wrappedValue, to: to.wrappedValue)
    }

    var tokenizer: any UITextInputTokenizer {
      self
    }

    func position(
      within range: UITextRange,
      farthestIn direction: UITextLayoutDirection
    ) -> UITextPosition? {
      guard let rangeBox = range as? TextRangeBox else { return nil }

      let start = rangeBox.wrappedStart
      let end = rangeBox.wrappedEnd
      let startRect = model.caretRect(for: start)
      let endRect = model.caretRect(for: end)

      let position: TextPosition
      switch direction {
      case .left:
        position = startRect.minX <= endRect.minX ? start : end
      case .right:
        position = startRect.maxX >= endRect.maxX ? start : end
      case .up:
        position = startRect.minY <= endRect.minY ? start : end
      case .down:
        position = startRect.maxY >= endRect.maxY ? start : end
      @unknown default:
        position = end
      }

      return TextPositionBox(position)
    }

    func characterRange(
      byExtending position: UITextPosition,
      in direction: UITextLayoutDirection
    ) -> UITextRange? {
      guard let positionBox = position as? TextPositionBox else { return nil }
      guard
        let nextPosition = adjacentPosition(from: positionBox.wrappedValue, in: direction)
      else {
        return nil
      }

      return TextRangeBox(
        TextRange(from: positionBox.wrappedValue, to: nextPosition)
      )
    }

    func baseWritingDirection(
      for position: UITextPosition,
      in direction: UITextStorageDirection
    ) -> NSWritingDirection {
      // Not applicable for non-editable interaction mode?
      return .natural
    }

    func setBaseWritingDirection(_: NSWritingDirection, for _: UITextRange) {
      // Do nothing
    }

    func firstRect(for range: UITextRange) -> CGRect {
      guard let rangeBox = range as? TextRangeBox else { return .zero }
      return model.firstRect(for: rangeBox.wrappedValue)
    }

    func caretRect(for position: UITextPosition) -> CGRect {
      guard let positionBox = position as? TextPositionBox else { return .zero }
      return model.caretRect(for: positionBox.wrappedValue)
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
      guard let rangeBox = range as? TextRangeBox else { return [] }
      return model.selectionRects(for: rangeBox.wrappedValue)
        .map(TextSelectionRectBox.init)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
      model.closestPosition(to: point).map(TextPositionBox.init)
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
      guard let rangeBox = range as? TextRangeBox else { return nil }
      return model.closestPosition(
        to: point,
        within: rangeBox.wrappedValue
      ).map(TextPositionBox.init)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
      model.characterRange(at: point).map(TextRangeBox.init)
    }

    var textInputView: UIView {
      self
    }

    var isEditable: Bool {
      false
    }

    func attributedText(in range: UITextRange) -> NSAttributedString {
      guard let rangeBox = range as? TextRangeBox else { return .init() }
      return model.attributedText(in: rangeBox.wrappedValue)
    }
  }

  private extension UITextInteractionView {
    func adjacentPosition(
      from position: TextPosition,
      in direction: UITextLayoutDirection
    ) -> TextPosition? {
      switch direction {
      case .left:
        let offset = model.layoutDirection(at: position) == .rightToLeft ? 1 : -1
        return model.position(from: position, offset: offset)
      case .right:
        let offset = model.layoutDirection(at: position) == .rightToLeft ? -1 : 1
        return model.position(from: position, offset: offset)
      case .up:
        return model.positionAbove(position, anchor: position)
      case .down:
        return model.positionBelow(position, anchor: position)
      @unknown default:
        return nil
      }
    }
  }

  private extension UITextLayoutDirection {
    var reversed: Self {
      switch self {
      case .right:
        .left
      case .left:
        .right
      case .up:
        .down
      case .down:
        .up
      @unknown default:
        self
      }
    }
  }
#endif
