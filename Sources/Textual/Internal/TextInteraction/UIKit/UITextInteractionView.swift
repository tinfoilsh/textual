#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI
  import os
  import UniformTypeIdentifiers

  // MARK: - Overview
  //
  // `UITextInteractionView` implements selection and link interaction on iOS-family platforms.
  //
  // The view sits in an overlay above one or more rendered `Text` fragments. It uses
  // `TextSelectionModel` to translate touch locations into URLs and selection ranges, and it
  // respects `exclusionRects` so embedded scrollable regions can continue to handle gestures.
  // Selection UI is provided by `UITextInteraction` configured for non-editable content.

  final class UITextInteractionView: UIView {
    override var canBecomeFirstResponder: Bool {
      true
    }

    var model: TextSelectionModel
    var exclusionRects: [CGRect]
    var openURL: OpenURLAction

    weak var inputDelegate: (any UITextInputDelegate)?

    let logger = Logger(category: .textInteraction)

    private(set) lazy var _tokenizer = UITextInputStringTokenizer(textInput: self)
    private var selectionInteraction: UITextInteraction?
    private var tapGesture: UITapGestureRecognizer?

    init(
      model: TextSelectionModel,
      exclusionRects: [CGRect],
      openURL: OpenURLAction
    ) {
      self.model = model
      self.exclusionRects = exclusionRects
      self.openURL = openURL

      super.init(frame: .zero)
      self.backgroundColor = .clear

      setUpCallbacks()
      installInteractionIfNeeded()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      for exclusionRect in exclusionRects {
        if exclusionRect.contains(point) {
          return false
        }
      }
      return super.point(inside: point, with: event)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
      switch action {
      case #selector(copy(_:)), #selector(share(_:)):
        return !(model.selectedRange?.isCollapsed ?? true)
      default:
        return false
      }
    }

    override func copy(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let formatter = Formatter(attributedText)

      UIPasteboard.general.setItems(
        [
          [
            UTType.plainText.identifier: formatter.plainText(),
            UTType.html.identifier: formatter.html(),
          ]
        ]
      )
    }

    private func setUpCallbacks() {
      model.selectionWillChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionWillChange(self)
      }
      model.selectionDidChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionDidChange(self)
        if let selectedRange = self.model.selectedRange,
          !selectedRange.isCollapsed,
          !self.isFirstResponder
        {
          _ = self.becomeFirstResponder()
        }
      }
    }

    func installInteractionIfNeeded() {
      guard selectionInteraction == nil, model.hasText else { return }

      let interaction = UITextInteraction(for: .nonEditable)

      let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      addGestureRecognizer(tap)
      self.tapGesture = tap

      interaction.textInput = self
      interaction.delegate = self

      for gesture in interaction.gesturesForFailureRequirements {
        tap.require(toFail: gesture)
      }

      addInteraction(interaction)
      self.selectionInteraction = interaction
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
      let location = gesture.location(in: self)
      guard let url = model.url(for: location) else {
        if model.selectedRange != nil {
          model.selectedRange = nil
          resignFirstResponder()
        }
        return
      }
      openURL(url)
    }

    @objc private func share(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let itemSource = TextActivityItemSource(attributedString: attributedText)

      let activityViewController = UIActivityViewController(
        activityItems: [itemSource],
        applicationActivities: nil
      )

      if let popover = activityViewController.popoverPresentationController {
        let rect =
          model.selectionRects(for: selectedRange)
          .last?.rect.integral ?? .zero
        popover.sourceView = self
        popover.sourceRect = rect
      }

      if let windowScene = window?.windowScene,
        let viewController = windowScene.windows.first?.rootViewController
      {
        viewController.present(activityViewController, animated: true)
      }
    }
  }

  extension UITextInteractionView: UITextInteractionDelegate {
    func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
      logger.debug("interactionShouldBegin(at: \(point.logDescription)) -> true")
      return true
    }

    func interactionWillBegin(_ interaction: UITextInteraction) {
      logger.debug("interactionWillBegin")
      model.setInteractionActive(true)
    }

    func interactionDidEnd(_ interaction: UITextInteraction) {
      logger.debug("interactionDidEnd")
      model.setInteractionActive(false)
    }
  }

  extension Logger.Textual.Category {
    fileprivate static let textInteraction = Self(rawValue: "textInteraction")
  }
#endif
