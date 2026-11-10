#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import Foundation
  import SwiftUI
  import Testing
  import UIKit

  @testable import Textual

  @MainActor
  struct UITextInteractionViewTests {
    @Test
    func installsSelectionWhenTextIsLaidOutWithoutAViewUpdate() throws {
      // given
      let model = TextSelectionModel()
      let view = UITextInteractionView(
        model: model,
        exclusionRects: [],
        openURL: OpenURLAction { _ in .handled }
      )
      let url = try #require(
        Bundle.module.url(
          forResource: "Fixtures/TextSelectionModel/two-paragraphs-bidi",
          withExtension: "json"
        )
      )
      let layoutCollection = try JSONDecoder().decode(
        CodableTextLayoutCollection.self,
        from: Data(contentsOf: url)
      )
      #expect(!view.interactions.contains { $0 is UITextInteraction })

      // when
      model.setLayoutCollection(layoutCollection)

      // then
      #expect(view.interactions.contains { $0 is UITextInteraction })
    }

    @Test
    func keepsCopyAvailableAfterSelectionGestureEnds() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let view = UITextInteractionView(
        model: model,
        exclusionRects: [],
        openURL: OpenURLAction { _ in .handled }
      )
      let interaction = try #require(
        view.interactions.compactMap { $0 as? UITextInteraction }.first
      )
      let selectedRange = TextRange(start: model.startPosition, end: model.endPosition)

      view.interactionWillBegin(interaction)
      model.selectedRange = selectedRange
      view.interactionDidEnd(interaction)

      #expect(model.selectedRange == selectedRange)
      #expect(
        view.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil)
      )
    }
  }
#endif
