import XCTest
@testable import Meetless

final class TranscriptAutoScrollStateTests: XCTestCase {
    func testStartsPinnedAndAllowsAutoScroll() {
        let state = TranscriptAutoScrollState()

        XCTAssertTrue(state.shouldAutoScrollOnRowChange)
        XCTAssertTrue(state.isPinnedToBottom)
        XCTAssertFalse(state.isUserScrolling)
    }

    func testUserScrollAwayFromBottomPausesAutoScroll() {
        var state = TranscriptAutoScrollState()

        state.handleScrollPhaseChange(
            wasUserScrolling: false,
            isUserScrolling: true,
            isAtBottom: false
        )

        XCTAssertFalse(state.shouldAutoScrollOnRowChange)
        XCTAssertFalse(state.isPinnedToBottom)
        XCTAssertTrue(state.isUserScrolling)
    }

    func testContentGrowthWhilePinnedDoesNotPauseAutoScroll() {
        var state = TranscriptAutoScrollState()

        state.handleGeometryChange(isAtBottom: false)

        XCTAssertTrue(state.shouldAutoScrollOnRowChange)
        XCTAssertTrue(state.isPinnedToBottom)
    }

    func testUserScrollBackToBottomResumesAutoScroll() {
        var state = TranscriptAutoScrollState()
        state.handleScrollPhaseChange(
            wasUserScrolling: false,
            isUserScrolling: true,
            isAtBottom: false
        )

        state.handleGeometryChange(isAtBottom: true)

        XCTAssertTrue(state.shouldAutoScrollOnRowChange)
        XCTAssertTrue(state.isPinnedToBottom)
    }

    func testEndingUserScrollAwayFromBottomKeepsAutoScrollPaused() {
        var state = TranscriptAutoScrollState()
        state.handleScrollPhaseChange(
            wasUserScrolling: false,
            isUserScrolling: true,
            isAtBottom: false
        )

        state.handleScrollPhaseChange(
            wasUserScrolling: true,
            isUserScrolling: false,
            isAtBottom: false
        )

        XCTAssertFalse(state.shouldAutoScrollOnRowChange)
        XCTAssertFalse(state.isPinnedToBottom)
        XCTAssertFalse(state.isUserScrolling)
    }
}

final class RecordingTranscriptPanelHeightPreferenceTests: XCTestCase {
    func testClampsTranscriptPanelHeightToSupportedRange() {
        XCTAssertEqual(
            RecordingTranscriptPanelHeightPreference.clamped(RecordingTranscriptPanelHeightPreference.minimumHeight - 40),
            RecordingTranscriptPanelHeightPreference.minimumHeight
        )
        XCTAssertEqual(
            RecordingTranscriptPanelHeightPreference.clamped(RecordingTranscriptPanelHeightPreference.maximumHeight + 40),
            RecordingTranscriptPanelHeightPreference.maximumHeight
        )
        XCTAssertEqual(
            RecordingTranscriptPanelHeightPreference.clamped(RecordingTranscriptPanelHeightPreference.defaultHeight),
            RecordingTranscriptPanelHeightPreference.defaultHeight
        )
    }
}
