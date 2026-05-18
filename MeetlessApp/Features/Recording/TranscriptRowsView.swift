import SwiftUI

struct TranscriptRowsView: View {
    private static let bottomAnchorID = "transcript-bottom-anchor"
    private static let bottomTolerance: CGFloat = 8

    let rows: [TranscriptDisplayRow]
    let maxHeight: CGFloat

    @State private var autoScrollState = TranscriptAutoScrollState()

    init(chunks: [CommittedTranscriptChunk], maxHeight: CGFloat = 260) {
        self.init(rows: chunks.map(TranscriptDisplayRow.init(chunk:)), maxHeight: maxHeight)
    }

    init(rows: [TranscriptDisplayRow], maxHeight: CGFloat = 260) {
        self.rows = rows.sorted { first, second in
            if first.startTime == second.startTime {
                return first.sequenceNumber < second.sequenceNumber
            }

            return first.startTime < second.startTime
        }
        self.maxHeight = maxHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                TranscriptRow(row: row)

                                if index < rows.count - 1 {
                                    HairlineDivider()
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(Self.bottomAnchorID)
                        }
                    }
                    .onAppear {
                        autoScrollState.markScrolledToBottom()
                        scrollToBottom(proxy)
                    }
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        Self.isAtBottom(geometry)
                    } action: { _, isAtBottom in
                        autoScrollState.handleGeometryChange(isAtBottom: isAtBottom)
                    }
                    .onScrollPhaseChange { oldPhase, newPhase, context in
                        autoScrollState.handleScrollPhaseChange(
                            wasUserScrolling: oldPhase.isUserDriven,
                            isUserScrolling: newPhase.isUserDriven,
                            isAtBottom: Self.isAtBottom(context.geometry)
                        )
                    }
                    .onChange(of: scrollSignature) { _, _ in
                        guard autoScrollState.shouldAutoScrollOnRowChange else {
                            return
                        }

                        scrollToBottom(proxy)
                    }
                }
                .frame(maxHeight: maxHeight)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var scrollSignature: String {
        rows
            .map { row in
                "\(row.id):\(row.text.count):\(row.originalText?.count ?? 0):\(row.endFrameIndex):\(row.state)"
            }
            .joined(separator: "|")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private static func isAtBottom(_ geometry: ScrollGeometry) -> Bool {
        geometry.visibleRect.maxY >= geometry.contentSize.height - bottomTolerance
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

            Text("Transcript will appear as speech is transcribed.")
                .font(MeetlessDesignTokens.Typography.body)
                .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

struct TranscriptAutoScrollState: Equatable {
    private(set) var isPinnedToBottom = true
    private(set) var isUserScrolling = false

    var shouldAutoScrollOnRowChange: Bool {
        isPinnedToBottom
    }

    mutating func markScrolledToBottom() {
        isPinnedToBottom = true
    }

    mutating func handleGeometryChange(isAtBottom: Bool) {
        guard isUserScrolling || isAtBottom else {
            return
        }

        isPinnedToBottom = isAtBottom
    }

    mutating func handleScrollPhaseChange(
        wasUserScrolling: Bool,
        isUserScrolling: Bool,
        isAtBottom: Bool
    ) {
        self.isUserScrolling = isUserScrolling

        if wasUserScrolling || isUserScrolling {
            isPinnedToBottom = isAtBottom
        } else if isAtBottom {
            isPinnedToBottom = true
        }
    }
}

private extension ScrollPhase {
    var isUserDriven: Bool {
        switch self {
        case .tracking, .interacting, .decelerating:
            return true
        case .idle, .animating:
            return false
        @unknown default:
            return isScrolling
        }
    }
}

private struct TranscriptRow: View {
    let row: TranscriptDisplayRow

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 0) {
            GridRow {
                Text(formattedStartTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
                    .frame(width: 44, alignment: .leading)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    if let originalText {
                        Text("Original: \(originalText)")
                            .font(MeetlessDesignTokens.Typography.caption)
                            .italic()
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Translate: \(row.text)")
                            .font(MeetlessDesignTokens.Typography.body)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(textColor)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } else {
                        Text(row.text)
                            .font(MeetlessDesignTokens.Typography.body)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(textColor)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let statusText {
                        Text(statusText)
                            .font(MeetlessDesignTokens.Typography.caption)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var originalText: String? {
        let trimmedOriginalText = row.originalText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedText = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginalText.isEmpty, trimmedOriginalText != trimmedText else {
            return nil
        }

        return trimmedOriginalText
    }

    private var accessibilityText: String {
        if let originalText {
            return "\(formattedStartTime), original: \(originalText), translate: \(row.text)"
        }

        return "\(formattedStartTime), \(row.text)"
    }

    private var formattedStartTime: String {
        let totalSeconds = max(0, Int(row.startTime.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%01d:%02d", minutes, seconds)
    }

    private var statusText: String? {
        switch row.state {
        case .committed:
            return nil
        case .pendingTranscript:
            return "Waiting for a complete phrase before translation"
        case .pendingTranslation:
            return "Translating"
        }
    }

    private var textColor: Color {
        switch row.state {
        case .committed:
            return MeetlessDesignTokens.Colors.primaryText
        case .pendingTranscript, .pendingTranslation:
            return MeetlessDesignTokens.Colors.secondaryText
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        TranscriptRowsView(chunks: [
            CommittedTranscriptChunk(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID(),
                source: .meeting,
                text: "We can keep every word local and still show stable chunks as they commit.",
                startFrameIndex: 0,
                endFrameIndex: 64_000,
                sampleRate: 16_000,
                sequenceNumber: 1
            ),
            CommittedTranscriptChunk(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
                source: .me,
                text: "That gives saved sessions the same transcript timeline the operator already saw.",
                startFrameIndex: 64_000,
                endFrameIndex: 128_000,
                sampleRate: 16_000,
                sequenceNumber: 2
            )
        ])

        TranscriptRowsView(chunks: [])
    }
    .padding()
    .frame(width: 460)
}
