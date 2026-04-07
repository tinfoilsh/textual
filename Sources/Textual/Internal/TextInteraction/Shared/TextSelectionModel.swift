#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  // MARK: - Overview
  //
  // `TextSelectionModel` is the shared state object that backs selection and interaction.
  //
  // Platform views (AppKit/UIKit) mutate `selectedRange` in response to gestures and editing
  // commands. The model delegates layout-specific work to a `TextLayoutCollection`, which can be
  // rebuilt at any time as SwiftUI resolves new `Text.Layout` values. When the layout collection
  // changes, the model attempts to reconcile the current selection into the new layout so the
  // selection stays stable across updates.

  @Observable
  final class TextSelectionModel {
    var selectedRange: TextRange? {
      willSet {
        selectionWillChange?()
      }
      didSet {
        if selectedRange != nil {
          selectionLayoutCollection = AnyTextLayoutCollection(layoutCollection)
          coordinator?.modelDidSelectText(self)
        } else {
          selectionLayoutCollection = nil
          deferredSelectedRange = nil
          deferredSelectionLayoutCollection = nil
        }
        selectionDidChange?()
      }
    }

    @ObservationIgnored
    var selectionWillChange: (() -> Void)?

    @ObservationIgnored
    var selectionDidChange: (() -> Void)?

    @ObservationIgnored
    private var layoutCollection: any TextLayoutCollection

    @ObservationIgnored
    private weak var coordinator: TextSelectionCoordinator?

    @ObservationIgnored
    private var selectionLayoutCollection: AnyTextLayoutCollection?

    @ObservationIgnored
    private var deferredSelectedRange: TextRange?

    @ObservationIgnored
    private var deferredSelectionLayoutCollection: AnyTextLayoutCollection?

    @ObservationIgnored
    private var isInteractionActive = false

    init(
      layoutCollection: any TextLayoutCollection = EmptyTextLayoutCollection(),
      coordinator: TextSelectionCoordinator? = nil
    ) {
      self.layoutCollection = layoutCollection
      setCoordinator(coordinator)
    }

    func setLayoutCollection(_ layoutCollection: any TextLayoutCollection) {
      guard !layoutCollection.isEqual(to: self.layoutCollection) else {
        return
      }

      let previousLayoutCollection = AnyTextLayoutCollection(self.layoutCollection)
      self.layoutCollection = layoutCollection

      guard let selectedRange else {
        return
      }

      let selectionLayoutCollection = self.selectionLayoutCollection ?? previousLayoutCollection

      guard layoutCollection.needsPositionReconciliation(with: selectionLayoutCollection) else {
        self.selectionLayoutCollection = AnyTextLayoutCollection(layoutCollection)
        return
      }

      let reconciledRange = layoutCollection.reconcileRange(
        selectedRange,
        from: selectionLayoutCollection
      )

      guard !isInteractionActive else {
        deferredSelectedRange = reconciledRange
        deferredSelectionLayoutCollection = AnyTextLayoutCollection(layoutCollection)
        return
      }

      guard reconciledRange != selectedRange else {
        self.selectionLayoutCollection = AnyTextLayoutCollection(layoutCollection)
        return
      }

      // Try to reconcile the selected text range
      self.selectedRange = reconciledRange
    }

    func setInteractionActive(_ isActive: Bool) {
      guard isInteractionActive != isActive else {
        return
      }

      isInteractionActive = isActive

      guard !isActive else {
        return
      }

      let deferredSelectedRange = self.deferredSelectedRange
      let deferredSelectionLayoutCollection = self.deferredSelectionLayoutCollection

      self.deferredSelectedRange = nil
      self.deferredSelectionLayoutCollection = nil

      guard deferredSelectedRange != selectedRange else {
        if let deferredSelectionLayoutCollection {
          selectionLayoutCollection = deferredSelectionLayoutCollection
        }
        return
      }

      if let deferredSelectionLayoutCollection {
        selectionLayoutCollection = deferredSelectionLayoutCollection
      }
      selectedRange = deferredSelectedRange
    }

    func setCoordinator(_ coordinator: TextSelectionCoordinator?) {
      if self.coordinator === coordinator {
        return
      }

      self.coordinator = coordinator
      coordinator?.register(self)
    }

    func url(for point: CGPoint) -> URL? {
      layoutCollection.url(for: point)
    }

    func layoutIndex(of layout: Text.Layout) -> Int? {
      layoutCollection.index(of: layout)
    }
  }

  extension TextSelectionModel {
    var hasText: Bool {
      layoutCollection.stringLength > 0
    }

    var startPosition: TextPosition {
      layoutCollection.startPosition
    }

    var endPosition: TextPosition {
      layoutCollection.endPosition
    }

    func attributedText(in range: TextRange) -> NSAttributedString {
      layoutCollection.attributedText(in: range)
    }

    func text(in range: TextRange) -> String {
      attributedText(in: range).string
    }

    func position(from position: TextPosition, offset: Int) -> TextPosition? {
      layoutCollection.position(from: position, offset: offset)
    }

    func offset(from: TextPosition, to: TextPosition) -> Int {
      layoutCollection.characterIndex(at: to) - layoutCollection.characterIndex(at: from)
    }

    func layoutDirection(at position: TextPosition) -> LayoutDirection {
      layoutCollection.layoutDirection(at: position.indexPath)
    }

    func firstRect(for range: TextRange) -> CGRect {
      layoutCollection.firstRect(for: range)
    }

    func caretRect(for position: TextPosition) -> CGRect {
      layoutCollection.caretRect(for: position)
    }

    func selectionRects(for range: TextRange) -> [TextSelectionRect] {
      layoutCollection.selectionRects(for: range)
    }

    func selectionRects(for range: TextRange, layout: Text.Layout) -> [TextSelectionRect] {
      layoutCollection.selectionRects(for: range, layout: layout)
    }

    func closestPosition(to point: CGPoint) -> TextPosition? {
      layoutCollection.closestPosition(to: point)
    }

    func closestPosition(to point: CGPoint, within range: TextRange) -> TextPosition? {
      guard let position = closestPosition(to: point) else { return nil }
      if position <= range.start { return range.start }
      if position >= range.end { return range.end }
      return position
    }

    func isPositionAtBlockBoundary(_ position: TextPosition) -> Bool {
      layoutCollection.isPositionAtBlockBoundary(position)
    }

    func positionAbove(_ position: TextPosition, anchor: TextPosition) -> TextPosition? {
      layoutCollection.positionAbove(position, anchor: anchor)
    }

    func positionBelow(_ position: TextPosition, anchor: TextPosition) -> TextPosition? {
      layoutCollection.positionBelow(position, anchor: anchor)
    }

    func characterRange(at point: CGPoint) -> TextRange? {
      layoutCollection.characterRange(at: point)
    }

    func blockStart(for position: TextPosition) -> TextPosition? {
      layoutCollection.blockStart(for: position)
    }

    func blockEnd(for position: TextPosition) -> TextPosition? {
      layoutCollection.blockEnd(for: position)
    }

    func blockRange(for position: TextPosition) -> TextRange? {
      layoutCollection.blockRange(for: position)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func wordRange(for position: TextPosition) -> TextRange? {
      layoutCollection.wordRange(for: position)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func nextWord(from position: TextPosition) -> TextPosition? {
      layoutCollection.nextWord(from: position)
    }

    @available(macOS 10.0, *)
    @available(iOS, unavailable)
    @available(visionOS, unavailable)
    func previousWord(from position: TextPosition) -> TextPosition? {
      layoutCollection.previousWord(from: position)
    }
  }
#endif
