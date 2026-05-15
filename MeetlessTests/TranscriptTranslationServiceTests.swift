import XCTest
@testable import Meetless

final class TranscriptTranslationServiceTests: XCTestCase {
    func testGeminiTranslationUsesTextOnlyGenerateContentRequest() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"candidates":[{"content":{"parts":[{"text":"Xin chao nhom."}]}}]}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: " gemini-key "),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            transport: transport
        )

        let translatedText = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello team.",
                sourceLanguage: .english,
                targetLanguage: .vietnamese,
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .gemini,
                    model: "gemini-test",
                    baseURL: URL(string: "https://gemini.test")!
                )
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])

        XCTAssertEqual(translatedText, "Xin chao nhom.")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "https://gemini.test/v1beta/models/gemini-test:generateContent?key=gemini-key")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(parts.count, 1)
        XCTAssertNotNil(parts.first?["text"] as? String)
        XCTAssertNil(parts.first?["fileData"])
    }

    func testOpenAITranslationUsesChatCompletionsEndpointAndParsesAssistantMessage() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"id":"chatcmpl-test","object":"chat.completion","choices":[{"index":0,"message":{"role":"assistant","content":"안녕하세요 팀."},"finish_reason":"stop"}]}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: " test-openai-key "),
            transport: transport
        )

        let translatedText = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello team.",
                sourceLanguage: .english,
                targetLanguage: .korean,
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .openAI,
                    model: "gemma4:31b",
                    baseURL: URL(string: "http://13.21.34.219:11434/v1/chat/completions")!
                )
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])

        XCTAssertEqual(translatedText, "안녕하세요 팀.")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "http://13.21.34.219:11434/v1/chat/completions")
        XCTAssertEqual(request.headers["Authorization"], "Bearer test-openai-key")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertEqual(body["model"] as? String, "gemma4:31b")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let message = try XCTUnwrap(messages.first)
        XCTAssertEqual(message["role"] as? String, "user")
        XCTAssertTrue((message["content"] as? String)?.contains("Return only the translated text") == true)
    }

    func testOpenAITranslationAppendsChatCompletionsPathForBaseURL() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"choices":[{"message":{"role":"assistant","content":"Xin chao."}}]}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: "openai-key"),
            transport: transport
        )

        _ = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello.",
                sourceLanguage: .english,
                targetLanguage: .vietnamese,
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .openAI,
                    model: "gpt-test",
                    baseURL: URL(string: "https://openai.test")!
                )
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(request.url.absoluteString, "https://openai.test/v1/chat/completions")
    }

    func testMissingProviderKeyMapsToSafeTranslationError() async throws {
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            transport: FixtureTranscriptTranslationHTTPTransport(responses: [])
        )

        do {
            _ = try await service.translate(
                TranscriptTranslationRequest(
                    text: "Hello.",
                    sourceLanguage: .english,
                    targetLanguage: .korean,
                    providerConfig: TranscriptTranslationProviderConfiguration(
                        provider: .openAI,
                        model: "gpt-test",
                        baseURL: URL(string: "https://openai.test")!
                    )
                )
            )
            XCTFail("Expected missing OpenAI key to fail.")
        } catch let error as TranscriptTranslationError {
            XCTAssertEqual(error, .missingAPIKey(provider: .openAI))
            XCTAssertTrue(error.safeUserMessage.contains("API key is missing"))
        }
    }
}

final class TranscriptCoordinatorTranslationTests: XCTestCase {
    func testSourceEqualsTargetSkipsLLMAndCommitsOriginalText() async throws {
        let fixture = try Self.makeCoordinatorFixture(
            workerText: "Hello team.",
            translator: FixtureTranscriptTranslator(result: .failure(TranscriptTranslationError.client))
        )
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .english,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let chunk = try await MeetlessTestSupport.waitForValue(description: "committed original chunk") {
            let chunks = await fixture.coordinator.currentTranscriptChunks()
            return chunks.first
        }
        let requestCount = await fixture.translator.requestCount

        XCTAssertEqual(chunk.text, "Hello team.")
        XCTAssertNil(chunk.originalText)
        XCTAssertEqual(chunk.translationStatus, .original)
        XCTAssertEqual(chunk.sourceLanguageCode, "en")
        XCTAssertEqual(chunk.outputLanguageCode, "en")
        XCTAssertEqual(requestCount, 0)
    }

    func testSuccessfulTranslationCommitsTranslatedTextAndHiddenOriginalText() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Xin chao nhom."))
        let fixture = try Self.makeCoordinatorFixture(workerText: "Hello team.", translator: translator)
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let chunk = try await MeetlessTestSupport.waitForValue(description: "committed translated chunk") {
            let chunks = await fixture.coordinator.currentTranscriptChunks()
            return chunks.first
        }
        let requests = await translator.requests
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(chunk.text, "Xin chao nhom.")
        XCTAssertEqual(chunk.originalText, "Hello team.")
        XCTAssertEqual(chunk.sourceLanguageCode, "en")
        XCTAssertEqual(chunk.outputLanguageCode, "vi")
        XCTAssertEqual(chunk.translationProvider, .gemini)
        XCTAssertEqual(chunk.translationStatus, .translated)
        XCTAssertEqual(request.targetLanguage, .vietnamese)
    }

    func testFailedTranslationCommitsOriginalTextAndMarksHealthDegraded() async throws {
        let translator = FixtureTranscriptTranslator(
            result: .failure(TranscriptTranslationError.provider(provider: .gemini, statusCode: 503))
        )
        let fixture = try Self.makeCoordinatorFixture(workerText: "Hello team.", translator: translator)
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .korean,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let chunk = try await MeetlessTestSupport.waitForValue(description: "fallback original chunk") {
            let chunks = await fixture.coordinator.currentTranscriptChunks()
            return chunks.first
        }
        let health = await fixture.coordinator.currentHealthSnapshot()

        XCTAssertEqual(chunk.text, "Hello team.")
        XCTAssertNil(chunk.originalText)
        XCTAssertEqual(chunk.outputLanguageCode, "ko")
        XCTAssertEqual(chunk.translationProvider, .gemini)
        XCTAssertEqual(chunk.translationStatus, .failed)
        XCTAssertTrue(health.hasDegradedSource)
        XCTAssertTrue(health.latestEvent?.contains("translation failed") == true)
    }

    private static func makeCoordinatorFixture(
        workerText: String,
        translator: FixtureTranscriptTranslator
    ) throws -> (
        directoryURL: URL,
        coordinator: TranscriptCoordinator,
        translator: FixtureTranscriptTranslator,
        chunk: SourceAudioChunk
    ) {
        let directoryURL = try MeetlessTestSupport.makeTemporaryDirectory(prefix: "TranscriptCoordinatorTranslationTests")
        let waveURL = directoryURL.appendingPathComponent("meeting.wav", isDirectory: false)
        try MeetlessTestSupport.writePCM16WaveFile(to: waveURL, sampleCount: 320)
        let coordinator = TranscriptCoordinator(
            meetingWorker: FixtureTranscriptWorker(text: workerText),
            meWorker: FixtureTranscriptWorker(text: ""),
            translator: translator,
            minimumCommitSeconds: 0.01,
            maximumCommitSeconds: 0.02
        )
        let chunk = SourceAudioChunk(
            source: .meeting,
            fileURL: waveURL,
            sampleRate: 16_000,
            channelCount: 1,
            startFrameIndex: 0,
            endFrameIndex: 320
        )
        return (directoryURL, coordinator, translator, chunk)
    }

    private static func providerConfig() -> TranscriptTranslationProviderConfiguration {
        TranscriptTranslationProviderConfiguration(
            provider: .gemini,
            model: "gemini-test",
            baseURL: URL(string: "https://gemini.test")!
        )
    }
}

private struct FixtureTranscriptWorker: TranscriptWindowTranscribing {
    let text: String

    func transcribeIncrementalWindow(samples: [Float]) async throws -> String {
        text
    }
}

private actor FixtureTranscriptTranslator: TranscriptTranslating {
    private let result: Result<String, Error>
    private(set) var requests: [TranscriptTranslationRequest] = []

    init(result: Result<String, Error>) {
        self.result = result
    }

    var requestCount: Int {
        requests.count
    }

    func translate(_ request: TranscriptTranslationRequest) async throws -> String {
        requests.append(request)
        return try result.get()
    }
}

private actor FixtureTranscriptTranslationHTTPTransport: TranscriptTranslationHTTPTransport {
    private var queuedResponses: [TranscriptTranslationHTTPResponse]
    private(set) var requests: [TranscriptTranslationHTTPRequest] = []

    init(responses: [TranscriptTranslationHTTPResponse]) {
        self.queuedResponses = responses
    }

    func send(_ request: TranscriptTranslationHTTPRequest) async throws -> TranscriptTranslationHTTPResponse {
        requests.append(request)
        guard !queuedResponses.isEmpty else {
            return TranscriptTranslationHTTPResponse(statusCode: 500, body: Data())
        }

        return queuedResponses.removeFirst()
    }
}

private final class FixtureTranslationAPIKeyStore: GeminiAPIKeyStoring, OpenAIAPIKeyStoring {
    private let apiKey: String?

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func loadAPIKey() throws -> String? {
        apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {}

    func deleteAPIKey() throws {}
}
