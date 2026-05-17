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
                ),
                context: TranscriptTranslationContext(
                    domain: .informationTechnology
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
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)
        XCTAssertTrue(prompt.contains("Translation context: Information Technology"))
        XCTAssertTrue(prompt.contains("software, cloud, security, database, API"))
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
                ),
                context: TranscriptTranslationContext(
                    domain: .finance
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
        let prompt = try XCTUnwrap(message["content"] as? String)
        XCTAssertTrue(prompt.contains("Return only the translated text"))
        XCTAssertTrue(prompt.contains("Translation context: Finance"))
        XCTAssertTrue(prompt.contains("finance, accounting, budgeting"))
    }

    func testCustomPromptTemplateRendersForGemini() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"candidates":[{"content":{"parts":[{"text":"Bonjour equipe."}]}}]}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: "gemini-key"),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            transport: transport
        )

        _ = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello team.",
                sourceLanguage: .english,
                targetLanguage: TranscriptOutputLanguage(rawValue: "fr"),
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .gemini,
                    model: "gemini-test",
                    baseURL: URL(string: "https://gemini.test")!
                ),
                context: TranscriptTranslationContext(
                    domain: .customPrompt,
                    customPromptTemplate: "Only translate from {{source_language}} to {{target_language}}: {{transcript}}"
                )
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.body) as? [String: Any])
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])
        let prompt = try XCTUnwrap(parts.first?["text"] as? String)

        XCTAssertEqual(prompt, "Only translate from English to French: Hello team.")
    }

    func testInvalidCustomPromptTemplateFailsBeforeProviderRequest() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(responses: [])
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: "gemini-key"),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            transport: transport
        )

        do {
            _ = try await service.translate(
                TranscriptTranslationRequest(
                    text: "Hello team.",
                    sourceLanguage: .english,
                    targetLanguage: .vietnamese,
                    providerConfig: TranscriptTranslationProviderConfiguration(
                        provider: .gemini,
                        model: "gemini-test",
                        baseURL: URL(string: "https://gemini.test")!
                    ),
                    context: TranscriptTranslationContext(
                        domain: .customPrompt,
                        customPromptTemplate: "Translate {{transcript}} to {{target_language}}."
                    )
                )
            )
            XCTFail("Expected invalid request for missing placeholder.")
        } catch let error as TranscriptTranslationError {
            XCTAssertEqual(error, .invalidRequest)
        }

        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
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

    func testGoogleTranslateUsesBasicV2QueryParametersAndParsesTranslatedText() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"data":{"translations":[{"translatedText":"Xin chao nhom."}]}}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            googleTranslateAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: " google-key "),
            transport: transport
        )

        let translatedText = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello team.",
                sourceLanguage: .english,
                targetLanguage: .vietnamese,
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .googleTranslate,
                    model: "unused",
                    baseURL: URL(string: "https://translation.test")!
                ),
                context: TranscriptTranslationContext(domain: .legal)
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        let components = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(translatedText, "Xin chao nhom.")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "translation.test")
        XCTAssertEqual(components.path, "/language/translate/v2")
        XCTAssertEqual(queryItems["q"], "Hello team.")
        XCTAssertEqual(queryItems["source"], "en")
        XCTAssertEqual(queryItems["target"], "vi")
        XCTAssertEqual(queryItems["format"], "text")
        XCTAssertEqual(queryItems["key"], "google-key")
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertTrue(request.body.isEmpty)
    }

    func testGoogleTranslateOmitsSourceForAutoDetect() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"data":{"translations":[{"translatedText":"Xin chao."}]}}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            googleTranslateAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: "google-key"),
            transport: transport
        )

        _ = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello.",
                sourceLanguage: .autoDetect,
                targetLanguage: .vietnamese,
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .googleTranslate,
                    model: "unused",
                    baseURL: URL(string: "https://translation.test")!
                )
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        let components = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertNil(queryItems["source"])
        XCTAssertEqual(queryItems["target"], "vi")
    }

    func testGoogleTranslateAcceptsFullEndpointBaseURL() async throws {
        let transport = FixtureTranscriptTranslationHTTPTransport(
            responses: [
                TranscriptTranslationHTTPResponse(
                    statusCode: 200,
                    body: Data(#"{"data":{"translations":[{"translatedText":"안녕하세요."}]}}"#.utf8)
                )
            ]
        )
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            googleTranslateAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: "google-key"),
            transport: transport
        )

        _ = try await service.translate(
            TranscriptTranslationRequest(
                text: "Hello.",
                sourceLanguage: .english,
                targetLanguage: .korean,
                providerConfig: TranscriptTranslationProviderConfiguration(
                    provider: .googleTranslate,
                    model: "unused",
                    baseURL: URL(string: "https://translation.test/language/translate/v2")!
                )
            )
        )
        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)

        XCTAssertTrue(request.url.absoluteString.hasPrefix("https://translation.test/language/translate/v2?"))
    }

    func testMissingProviderKeyMapsToSafeTranslationError() async throws {
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            googleTranslateAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
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

    func testGoogleTranslateMalformedResponseMapsToProviderSpecificError() async throws {
        let service = TranscriptTranslationService(
            geminiAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            openAIAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: nil),
            googleTranslateAPIKeyStore: FixtureTranslationAPIKeyStore(apiKey: "google-key"),
            transport: FixtureTranscriptTranslationHTTPTransport(
                responses: [
                    TranscriptTranslationHTTPResponse(
                        statusCode: 200,
                        body: Data(#"{"data":{"translations":[{"translatedText":"   "}]}}"#.utf8)
                    )
                ]
            )
        )

        do {
            _ = try await service.translate(
                TranscriptTranslationRequest(
                    text: "Hello.",
                    sourceLanguage: .english,
                    targetLanguage: .korean,
                    providerConfig: TranscriptTranslationProviderConfiguration(
                        provider: .googleTranslate,
                        model: "unused",
                        baseURL: URL(string: "https://translation.test")!
                    )
                )
            )
            XCTFail("Expected malformed Google Translate response to fail.")
        } catch let error as TranscriptTranslationError {
            XCTAssertEqual(error, .malformedResponse(provider: .googleTranslate))
            XCTAssertTrue(error.safeUserMessage.contains("Google Translate returned"))
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

    func testIncompleteTranslationFragmentStaysLiveAndDoesNotCallTranslator() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Chung ta can."))
        let fixture = try Self.makeCoordinatorFixture(
            worker: FixtureTranscriptWorker(text: "We need to"),
            translator: translator,
            sampleCount: 160,
            minimumCommitSeconds: 0.01,
            maximumCommitSeconds: 0.01
        )
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let row = try await MeetlessTestSupport.waitForValue(description: "pending live transcript row") {
            let rows = await fixture.coordinator.currentLiveTranscriptRows()
            return rows.first
        }
        let committedChunks = await fixture.coordinator.currentTranscriptChunks()
        let requestCount = await translator.requestCount

        XCTAssertEqual(row.text, "We need to")
        XCTAssertEqual(row.state, .pendingTranscript)
        XCTAssertTrue(committedChunks.isEmpty)
        XCTAssertEqual(requestCount, 0)
    }

    func testSplitTranscriptFragmentsAreMergedBeforeTranslationRequest() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Chung ta can review API."))
        let fixture = try Self.makeCoordinatorFixture(
            worker: SequenceTranscriptWorker(texts: [
                "We need to",
                "review the API."
            ]),
            translator: translator,
            sampleCount: 320,
            minimumCommitSeconds: 0.01,
            maximumCommitSeconds: 0.01
        )
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig(),
            context: TranscriptTranslationContext(
                domain: .informationTechnology
            )
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let chunk = try await MeetlessTestSupport.waitForValue(description: "merged translated chunk") {
            let chunks = await fixture.coordinator.currentTranscriptChunks()
            return chunks.first
        }
        let requests = await translator.requests
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.text, "We need to review the API.")
        XCTAssertEqual(request.context.domain, .informationTechnology)
        XCTAssertEqual(chunk.text, "Chung ta can review API.")
        XCTAssertEqual(chunk.originalText, "We need to review the API.")
        XCTAssertEqual(chunk.startFrameIndex, 0)
        XCTAssertEqual(chunk.endFrameIndex, 320)
        XCTAssertEqual(chunk.translationStatus, .translated)
    }

    func testStopFlushesPendingTranslationFragment() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Chung ta can."))
        let fixture = try Self.makeCoordinatorFixture(
            worker: FixtureTranscriptWorker(text: "We need to"),
            translator: translator,
            sampleCount: 160,
            minimumCommitSeconds: 0.01,
            maximumCommitSeconds: 0.01
        )
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)
        _ = try await MeetlessTestSupport.waitForValue(description: "pending row before stop") {
            let rows = await fixture.coordinator.currentLiveTranscriptRows()
            return rows.first
        }

        let frozenChunks = await fixture.coordinator.freezeVisibleSnapshot()
        let requests = await translator.requests
        let request = try XCTUnwrap(requests.first)
        let chunk = try XCTUnwrap(frozenChunks.first)

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.text, "We need to")
        XCTAssertEqual(chunk.text, "Chung ta can.")
        XCTAssertEqual(chunk.originalText, "We need to")
        XCTAssertEqual(chunk.translationStatus, .translated)
    }

    func testSuccessfulTranslationCommitsTranslatedTextAndHiddenOriginalText() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Xin chao nhom."))
        let fixture = try Self.makeCoordinatorFixture(workerText: "Hello team.", translator: translator)
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig(),
            context: TranscriptTranslationContext(
                domain: .informationTechnology
            )
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
        XCTAssertEqual(request.context.domain, .informationTechnology)
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

    func testProtectedTranscriptMarkersAreRemovedBeforeTranslation() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Xin chao team."))
        let fixture = try Self.makeCoordinatorFixture(
            workerText: "Bắt đầu Hello team. Kết thúc",
            translator: translator
        )
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let chunk = try await MeetlessTestSupport.waitForValue(description: "translated chunk without protected markers") {
            let chunks = await fixture.coordinator.currentTranscriptChunks()
            return chunks.first
        }
        let requests = await translator.requests
        let request = try XCTUnwrap(requests.first)

        XCTAssertEqual(request.text, "Hello team.")
        XCTAssertEqual(chunk.originalText, "Hello team.")
        XCTAssertEqual(chunk.text, "Xin chao team.")
        XCTAssertFalse(chunk.text.contains("Bắt đầu"))
        XCTAssertFalse(chunk.text.contains("Kết thúc"))
    }

    func testProtectedMarkerOnlyTranscriptIsTreatedAsSilence() async throws {
        let worker = RecordingTranscriptWorker(text: "Kết thúc.")
        let translator = FixtureTranscriptTranslator(result: .success("Should not translate."))
        let fixture = try Self.makeCoordinatorFixture(
            worker: worker,
            translator: translator,
            sampleCount: 320,
            minimumCommitSeconds: 0.01,
            maximumCommitSeconds: 0.02
        )
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        _ = try await MeetlessTestSupport.waitForValue(description: "marker-only transcript processed") {
            await worker.didTranscribe ? true : nil
        }
        let chunks = await fixture.coordinator.currentTranscriptChunks()
        let requestCount = await translator.requestCount

        XCTAssertTrue(chunks.isEmpty)
        XCTAssertEqual(requestCount, 0)
    }

    func testDisabledSourceSelectionIgnoresIncomingChunksForThatSource() async throws {
        let translator = FixtureTranscriptTranslator(result: .success("Xin chao."))
        let fixture = try Self.makeCoordinatorFixture(workerText: "Hello team.", translator: translator)
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

        await fixture.coordinator.setSourceSelection(
            RecordingSourceSelection(meetingEnabled: false, meEnabled: true)
        )
        await fixture.coordinator.setTranslationConfiguration(
            sourceLanguage: .english,
            outputLanguage: .vietnamese,
            providerConfig: Self.providerConfig()
        )
        await fixture.coordinator.ingest(fixture.chunk)

        let chunks = await fixture.coordinator.currentTranscriptChunks()
        let requestCount = await translator.requestCount

        XCTAssertTrue(chunks.isEmpty)
        XCTAssertEqual(requestCount, 0)
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
        try makeCoordinatorFixture(
            worker: FixtureTranscriptWorker(text: workerText),
            translator: translator,
            sampleCount: 320,
            minimumCommitSeconds: 0.01,
            maximumCommitSeconds: 0.02
        )
    }

    private static func makeCoordinatorFixture(
        worker: any TranscriptWindowTranscribing,
        translator: FixtureTranscriptTranslator,
        sampleCount: Int,
        minimumCommitSeconds: Double,
        maximumCommitSeconds: Double
    ) throws -> (
        directoryURL: URL,
        coordinator: TranscriptCoordinator,
        translator: FixtureTranscriptTranslator,
        chunk: SourceAudioChunk
    ) {
        let directoryURL = try MeetlessTestSupport.makeTemporaryDirectory(prefix: "TranscriptCoordinatorTranslationTests")
        let waveURL = directoryURL.appendingPathComponent("meeting.wav", isDirectory: false)
        try MeetlessTestSupport.writePCM16WaveFile(to: waveURL, sampleCount: sampleCount)
        let coordinator = TranscriptCoordinator(
            meetingWorker: worker,
            meWorker: FixtureTranscriptWorker(text: ""),
            translator: translator,
            minimumCommitSeconds: minimumCommitSeconds,
            maximumCommitSeconds: maximumCommitSeconds
        )
        let chunk = SourceAudioChunk(
            source: .meeting,
            fileURL: waveURL,
            sampleRate: 16_000,
            channelCount: 1,
            startFrameIndex: 0,
            endFrameIndex: Int64(sampleCount)
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

private actor SequenceTranscriptWorker: TranscriptWindowTranscribing {
    private var texts: [String]

    init(texts: [String]) {
        self.texts = texts
    }

    func transcribeIncrementalWindow(samples: [Float]) async throws -> String {
        guard !texts.isEmpty else { return "" }
        return texts.removeFirst()
    }
}

private actor RecordingTranscriptWorker: TranscriptWindowTranscribing {
    private let text: String
    private(set) var didTranscribe = false

    init(text: String) {
        self.text = text
    }

    func transcribeIncrementalWindow(samples: [Float]) async throws -> String {
        didTranscribe = true
        return text
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

private final class FixtureTranslationAPIKeyStore: GeminiAPIKeyStoring, OpenAIAPIKeyStoring, GoogleTranslateAPIKeyStoring {
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
