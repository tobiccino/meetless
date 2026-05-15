import Foundation

enum TranscriptOutputLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case korean = "ko"
    case vietnamese = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .korean:
            return "Korean"
        case .vietnamese:
            return "Vietnamese"
        }
    }

    static let defaultLanguage: TranscriptOutputLanguage = .english

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? Self.defaultLanguage
    }

    init(transcriptionLanguage: TranscriptionLanguage) {
        switch transcriptionLanguage {
        case .english:
            self = .english
        case .korean:
            self = .korean
        }
    }
}

enum TranscriptTranslationProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini
    case openAI = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini:
            return "Gemini"
        case .openAI:
            return "OpenAI"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini:
            return "gemini-2.5-flash"
        case .openAI:
            return "gpt-5.4-mini"
        }
    }

    var defaultBaseURL: URL {
        switch self {
        case .gemini:
            return URL(string: "https://generativelanguage.googleapis.com")!
        case .openAI:
            return URL(string: "https://api.openai.com")!
        }
    }

    static let defaultProvider: TranscriptTranslationProvider = .gemini

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? Self.defaultProvider
    }
}

enum TranscriptTranslationStatus: String, Codable, Sendable {
    case original
    case translated
    case failed
}

struct TranscriptTranslationProviderConfiguration: Equatable, Sendable {
    let provider: TranscriptTranslationProvider
    let model: String
    let baseURL: URL
}

struct TranscriptTranslationRequest: Equatable, Sendable {
    let text: String
    let sourceLanguage: TranscriptionLanguage
    let targetLanguage: TranscriptOutputLanguage
    let providerConfig: TranscriptTranslationProviderConfiguration
}

protocol TranscriptTranslating: Sendable {
    func translate(_ request: TranscriptTranslationRequest) async throws -> String
}

enum TranscriptTranslationError: Error, Equatable, Sendable {
    case missingAPIKey(provider: TranscriptTranslationProvider)
    case invalidRequest
    case authentication(provider: TranscriptTranslationProvider, statusCode: Int)
    case provider(provider: TranscriptTranslationProvider, statusCode: Int)
    case malformedResponse(provider: TranscriptTranslationProvider)
    case client

    var safeUserMessage: String {
        switch self {
        case .missingAPIKey(let provider):
            return "Transcript translation is configured for \(provider.displayName), but its API key is missing. Meetless kept the original transcript text."
        case .invalidRequest:
            return "Transcript translation could not be prepared. Meetless kept the original transcript text."
        case .authentication(let provider, _):
            return "\(provider.displayName) rejected the saved translation API key. Meetless kept the original transcript text."
        case .provider(let provider, _):
            return "\(provider.displayName) could not translate this transcript window. Meetless kept the original transcript text."
        case .malformedResponse(let provider):
            return "\(provider.displayName) returned a translation Meetless could not read. Meetless kept the original transcript text."
        case .client:
            return "Meetless could not complete transcript translation. The original transcript text was kept."
        }
    }
}

struct TranscriptTranslationService: TranscriptTranslating {
    private let geminiAPIKeyStore: any GeminiAPIKeyStoring
    private let openAIAPIKeyStore: any OpenAIAPIKeyStoring
    private let transport: any TranscriptTranslationHTTPTransport
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        geminiAPIKeyStore: any GeminiAPIKeyStoring = KeychainGeminiAPIKeyStore(),
        openAIAPIKeyStore: any OpenAIAPIKeyStoring = KeychainOpenAIAPIKeyStore(),
        transport: any TranscriptTranslationHTTPTransport = URLSessionTranscriptTranslationHTTPTransport()
    ) {
        self.geminiAPIKeyStore = geminiAPIKeyStore
        self.openAIAPIKeyStore = openAIAPIKeyStore
        self.transport = transport
    }

    func translate(_ request: TranscriptTranslationRequest) async throws -> String {
        let trimmedText = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TranscriptTranslationError.invalidRequest
        }

        switch request.providerConfig.provider {
        case .gemini:
            return try await translateWithGemini(request, text: trimmedText)
        case .openAI:
            return try await translateWithOpenAI(request, text: trimmedText)
        }
    }

    private func translateWithGemini(
        _ request: TranscriptTranslationRequest,
        text: String
    ) async throws -> String {
        let apiKey = try loadAPIKey(
            provider: .gemini,
            loader: geminiAPIKeyStore.loadAPIKey
        )
        let url = try apiKeyURL(
            request.providerConfig.baseURL.appendingPathComponent(
                "v1beta/models/\(request.providerConfig.model):generateContent"
            ),
            apiKey: apiKey
        )
        let body = GeminiTranslationRequest(
            contents: [
                GeminiTranslationContent(
                    role: "user",
                    parts: [
                        GeminiTranslationPart(
                            text: Self.prompt(
                                text: text,
                                sourceLanguage: request.sourceLanguage.displayName,
                                targetLanguage: request.targetLanguage.displayName
                            )
                        )
                    ]
                )
            ]
        )
        let response = try await transport.send(
            TranscriptTranslationHTTPRequest(
                method: "POST",
                url: url,
                headers: ["Content-Type": "application/json"],
                body: try encoder.encode(body)
            )
        )
        try validate(response: response, provider: .gemini)
        return try parseGeminiText(response.body)
    }

    private func translateWithOpenAI(
        _ request: TranscriptTranslationRequest,
        text: String
    ) async throws -> String {
        let apiKey = try loadAPIKey(
            provider: .openAI,
            loader: openAIAPIKeyStore.loadAPIKey
        )
        let body = OpenAIChatCompletionsRequest(
            model: request.providerConfig.model,
            messages: [
                OpenAIChatMessage(
                    role: "user",
                    content: Self.prompt(
                        text: text,
                        sourceLanguage: request.sourceLanguage.displayName,
                        targetLanguage: request.targetLanguage.displayName
                    )
                )
            ]
        )
        let response = try await transport.send(
            TranscriptTranslationHTTPRequest(
                method: "POST",
                url: Self.openAIChatCompletionsURL(from: request.providerConfig.baseURL),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(body)
            )
        )
        try validate(response: response, provider: .openAI)
        return try parseOpenAIText(response.body)
    }

    private static func openAIChatCompletionsURL(from baseURL: URL) -> URL {
        let path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            return baseURL
        }

        if path.hasSuffix("v1") {
            return baseURL
                .appendingPathComponent("chat")
                .appendingPathComponent("completions")
        }

        return baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("chat")
            .appendingPathComponent("completions")
    }

    private func loadAPIKey(
        provider: TranscriptTranslationProvider,
        loader: () throws -> String?
    ) throws -> String {
        do {
            let apiKey = try loader()?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let apiKey, !apiKey.isEmpty else {
                throw TranscriptTranslationError.missingAPIKey(provider: provider)
            }

            return apiKey
        } catch let error as TranscriptTranslationError {
            throw error
        } catch {
            throw TranscriptTranslationError.client
        }
    }

    private func validate(
        response: TranscriptTranslationHTTPResponse,
        provider: TranscriptTranslationProvider
    ) throws {
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw TranscriptTranslationError.authentication(provider: provider, statusCode: response.statusCode)
            }

            throw TranscriptTranslationError.provider(provider: provider, statusCode: response.statusCode)
        }
    }

    private func parseGeminiText(_ data: Data) throws -> String {
        do {
            let envelope = try decoder.decode(GeminiTranslationEnvelope.self, from: data)
            let text = envelope.candidates
                .flatMap(\.content.parts)
                .compactMap(\.text)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            guard let text else {
                throw TranscriptTranslationError.malformedResponse(provider: .gemini)
            }

            return text
        } catch let error as TranscriptTranslationError {
            throw error
        } catch {
            throw TranscriptTranslationError.malformedResponse(provider: .gemini)
        }
    }

    private func parseOpenAIText(_ data: Data) throws -> String {
        do {
            let envelope = try decoder.decode(OpenAIChatCompletionsEnvelope.self, from: data)
            let text = envelope.choices
                .map(\.message.content)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            guard let text else {
                throw TranscriptTranslationError.malformedResponse(provider: .openAI)
            }

            return text
        } catch let error as TranscriptTranslationError {
            throw error
        } catch {
            throw TranscriptTranslationError.malformedResponse(provider: .openAI)
        }
    }

    private func apiKeyURL(_ url: URL, apiKey: String) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TranscriptTranslationError.invalidRequest
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        components.queryItems = queryItems

        guard let keyedURL = components.url else {
            throw TranscriptTranslationError.invalidRequest
        }

        return keyedURL
    }

    private static func prompt(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        """
        Translate this meeting transcript window from \(sourceLanguage) to \(targetLanguage).
        Return only the translated text. Preserve speaker meaning, numbers, names, and punctuation. Do not summarize, explain, add labels, or include the original text.

        Transcript:
        \(text)
        """
    }
}

protocol TranscriptTranslationHTTPTransport: Sendable {
    func send(_ request: TranscriptTranslationHTTPRequest) async throws -> TranscriptTranslationHTTPResponse
}

struct TranscriptTranslationHTTPRequest: Equatable, Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data
}

struct TranscriptTranslationHTTPResponse: Equatable, Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(statusCode: Int, headers: [String: String] = [:], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

struct URLSessionTranscriptTranslationHTTPTransport: TranscriptTranslationHTTPTransport {
    func send(_ request: TranscriptTranslationHTTPRequest) async throws -> TranscriptTranslationHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = 20
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? 0
        let headers = httpResponse?.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String else {
                return
            }

            result[key] = "\(entry.value)"
        } ?? [:]
        return TranscriptTranslationHTTPResponse(statusCode: statusCode, headers: headers, body: data)
    }
}

private struct GeminiTranslationRequest: Encodable {
    let contents: [GeminiTranslationContent]
}

private struct GeminiTranslationContent: Encodable {
    let role: String
    let parts: [GeminiTranslationPart]
}

private struct GeminiTranslationPart: Encodable {
    let text: String
}

private struct GeminiTranslationEnvelope: Decodable {
    let candidates: [GeminiTranslationCandidate]
}

private struct GeminiTranslationCandidate: Decodable {
    let content: GeminiTranslationContentEnvelope
}

private struct GeminiTranslationContentEnvelope: Decodable {
    let parts: [GeminiTranslationPartEnvelope]
}

private struct GeminiTranslationPartEnvelope: Decodable {
    let text: String?
}

private struct OpenAIChatCompletionsRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
}

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatCompletionsEnvelope: Decodable {
    let choices: [OpenAIChatChoice]
}

private struct OpenAIChatChoice: Decodable {
    let message: OpenAIChatMessage
}
