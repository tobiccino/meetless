import Foundation

struct TranscriptOutputLanguage: RawRepresentable, CaseIterable, Identifiable, Codable, Sendable, Equatable, Hashable {
    let rawValue: String
    let displayName: String

    var id: String { rawValue }

    static let english = TranscriptOutputLanguage(rawValue: "en", displayName: "English")
    static let korean = TranscriptOutputLanguage(rawValue: "ko", displayName: "Korean")
    static let vietnamese = TranscriptOutputLanguage(rawValue: "vi", displayName: "Vietnamese")
    static let defaultLanguage: TranscriptOutputLanguage = .english

    static let allCases: [TranscriptOutputLanguage] = TranscriptionLanguage.allCases
        .filter { !$0.isAutoDetect }
        .map { TranscriptOutputLanguage(rawValue: $0.rawValue, displayName: $0.displayName) }
        .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

    init(rawValue: String) {
        self = Self.allCases.first { $0.rawValue == rawValue } ?? Self.defaultLanguage
    }

    init(rawValue: String, displayName: String) {
        self.rawValue = rawValue
        self.displayName = displayName
    }

    init(storedValue: String?) {
        self = storedValue.map(Self.init(rawValue:)) ?? Self.defaultLanguage
    }

    init(transcriptionLanguage: TranscriptionLanguage) {
        guard !transcriptionLanguage.isAutoDetect else {
            self = Self.defaultLanguage
            return
        }

        self = Self(rawValue: transcriptionLanguage.rawValue)
    }
}

enum TranscriptTranslationProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini
    case openAI = "openai"
    case googleTranslate = "google_translate"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini:
            return "Gemini"
        case .openAI:
            return "OpenAI"
        case .googleTranslate:
            return "Google Translate"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini:
            return "gemini-2.5-flash"
        case .openAI:
            return "gpt-5.4-mini"
        case .googleTranslate:
            return "nmt"
        }
    }

    var defaultBaseURL: URL {
        switch self {
        case .gemini:
            return URL(string: "https://generativelanguage.googleapis.com")!
        case .openAI:
            return URL(string: "https://api.openai.com")!
        case .googleTranslate:
            return URL(string: "https://translation.googleapis.com")!
        }
    }

    static let defaultProvider: TranscriptTranslationProvider = .gemini

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? Self.defaultProvider
    }

    var modelPresets: [TranscriptTranslationModelPreset] {
        switch self {
        case .gemini:
            return [
                TranscriptTranslationModelPreset(
                    id: "gemini-2.5-flash",
                    displayName: "Gemini 2.5 Flash",
                    detail: "Stable, balanced price-performance for live translation."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-2.5-flash-lite",
                    displayName: "Gemini 2.5 Flash-Lite",
                    detail: "Stable, fastest and most cost-efficient."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-2.5-pro",
                    displayName: "Gemini 2.5 Pro",
                    detail: "Stable, stronger reasoning for difficult terminology."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-3-flash-preview",
                    displayName: "Gemini 3 Flash Preview",
                    detail: "Preview, newer balanced model for text output."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-3-pro-preview",
                    displayName: "Gemini 3 Pro Preview",
                    detail: "Preview, strongest reasoning; may cost more or have tighter limits."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-flash-latest",
                    displayName: "Gemini Flash Latest",
                    detail: "Alias that follows Google's latest Flash release."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-pro-latest",
                    displayName: "Gemini Pro Latest",
                    detail: "Alias that follows Google's latest Pro release."
                ),
                TranscriptTranslationModelPreset(
                    id: "gemini-2.0-flash-lite",
                    displayName: "Gemini 2.0 Flash-Lite",
                    detail: "Older low-latency option for compatibility."
                )
            ]
        case .openAI:
            return []
        case .googleTranslate:
            return []
        }
    }

    var usesLLMPromptContext: Bool {
        switch self {
        case .gemini, .openAI:
            return true
        case .googleTranslate:
            return false
        }
    }
}

struct TranscriptTranslationModelPreset: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let detail: String
}

enum TranscriptTranslationStatus: String, Codable, Sendable {
    case original
    case translated
    case failed
}

enum TranscriptTranslationDomain: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case informationTechnology
    case business
    case finance
    case legal
    case healthcare
    case education
    case salesMarketing
    case engineering
    case customerSupport
    case customPrompt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general:
            return "General"
        case .informationTechnology:
            return "Information Technology"
        case .business:
            return "Business"
        case .finance:
            return "Finance"
        case .legal:
            return "Legal"
        case .healthcare:
            return "Healthcare"
        case .education:
            return "Education"
        case .salesMarketing:
            return "Sales & Marketing"
        case .engineering:
            return "Engineering"
        case .customerSupport:
            return "Customer Support"
        case .customPrompt:
            return "Custom Prompt"
        }
    }

    var promptInstruction: String {
        switch self {
        case .general:
            return "Use natural meeting terminology without adding domain-specific assumptions."
        case .informationTechnology:
            return "Prefer standard software, cloud, security, database, API, infrastructure, and product-development terminology."
        case .business:
            return "Prefer clear business, operations, strategy, stakeholder, and project-management terminology."
        case .finance:
            return "Prefer accurate finance, accounting, budgeting, revenue, cost, investment, and reporting terminology."
        case .legal:
            return "Prefer accurate legal, compliance, contract, policy, and risk terminology while preserving the speaker's original intent."
        case .healthcare:
            return "Prefer accurate healthcare, clinical, patient-care, operations, and medical-administration terminology."
        case .education:
            return "Prefer accurate education, curriculum, assessment, learning, academic, and classroom terminology."
        case .salesMarketing:
            return "Prefer accurate sales, marketing, customer journey, campaign, pipeline, brand, and growth terminology."
        case .engineering:
            return "Prefer accurate engineering, product design, manufacturing, systems, quality, and technical operations terminology."
        case .customerSupport:
            return "Prefer accurate support, incident, troubleshooting, service-level, escalation, and customer-experience terminology."
        case .customPrompt:
            return ""
        }
    }

    static let defaultDomain: TranscriptTranslationDomain = .general

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.init(rawValue:)) ?? Self.defaultDomain
    }
}

struct TranscriptTranslationContext: Equatable, Sendable {
    let domain: TranscriptTranslationDomain
    let customPromptTemplate: String

    static let defaultContext = TranscriptTranslationContext(
        domain: .defaultDomain
    )

    init(
        domain: TranscriptTranslationDomain = .defaultDomain,
        customPromptTemplate: String = TranscriptPromptTemplate.defaultTemplate
    ) {
        self.domain = domain
        self.customPromptTemplate = customPromptTemplate
    }
}

enum TranscriptPromptTemplate {
    static let sourceLanguagePlaceholder = "{{source_language}}"
    static let targetLanguagePlaceholder = "{{target_language}}"
    static let transcriptPlaceholder = "{{transcript}}"
    static let requiredPlaceholders = [
        sourceLanguagePlaceholder,
        targetLanguagePlaceholder,
        transcriptPlaceholder
    ]

    static let defaultTemplate = """
    Translate this meeting transcript window from {{source_language}} to {{target_language}}.
    Return only the translated text. Preserve speaker meaning, numbers, names, and punctuation. Do not summarize, explain, add labels, or include the original text.

    Transcript:
    {{transcript}}
    """

    static func normalizedTemplate(_ template: String?) -> String {
        let trimmed = template?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultTemplate : trimmed
    }

    static func missingPlaceholders(in template: String) -> [String] {
        requiredPlaceholders.filter { !template.contains($0) }
    }

    static func isValid(_ template: String) -> Bool {
        missingPlaceholders(in: template).isEmpty
    }

    static func render(
        template: String,
        sourceLanguage: String,
        targetLanguage: String,
        transcript: String
    ) -> String? {
        guard isValid(template) else { return nil }
        return template
            .replacingOccurrences(of: sourceLanguagePlaceholder, with: sourceLanguage)
            .replacingOccurrences(of: targetLanguagePlaceholder, with: targetLanguage)
            .replacingOccurrences(of: transcriptPlaceholder, with: transcript)
    }
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
    let context: TranscriptTranslationContext

    init(
        text: String,
        sourceLanguage: TranscriptionLanguage,
        targetLanguage: TranscriptOutputLanguage,
        providerConfig: TranscriptTranslationProviderConfiguration,
        context: TranscriptTranslationContext = .defaultContext
    ) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.providerConfig = providerConfig
        self.context = context
    }
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

struct ProviderAPIKeyTestRequest: Equatable, Sendable {
    let provider: TranscriptTranslationProvider
    let apiKey: String
    let baseURL: URL
}

enum ProviderAPIKeyTestError: Error, Equatable, Sendable {
    case missingAPIKey(provider: TranscriptTranslationProvider)
    case authentication(provider: TranscriptTranslationProvider, statusCode: Int)
    case provider(provider: TranscriptTranslationProvider, statusCode: Int)
    case malformedResponse(provider: TranscriptTranslationProvider)
    case client(provider: TranscriptTranslationProvider)

    var safeUserMessage: String {
        switch self {
        case .missingAPIKey(let provider):
            return "Enter or save a \(provider.displayName) API key before testing."
        case .authentication(let provider, _):
            return "\(provider.displayName) rejected this API key."
        case .provider(let provider, _):
            return "\(provider.displayName) could not validate the key right now."
        case .malformedResponse(let provider):
            return "\(provider.displayName) returned a response Meetless could not read."
        case .client(let provider):
            return "Meetless could not reach \(provider.displayName). Check your connection and try again."
        }
    }
}

protocol ProviderAPIKeyTesting: Sendable {
    func testAPIKey(_ request: ProviderAPIKeyTestRequest) async throws
}

struct ProviderAPIKeyTestService: ProviderAPIKeyTesting {
    private let transport: any TranscriptTranslationHTTPTransport
    private let decoder = JSONDecoder()

    init(transport: any TranscriptTranslationHTTPTransport = URLSessionTranscriptTranslationHTTPTransport()) {
        self.transport = transport
    }

    func testAPIKey(_ request: ProviderAPIKeyTestRequest) async throws {
        let apiKey = request.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw ProviderAPIKeyTestError.missingAPIKey(provider: request.provider)
        }

        let httpRequest = try makeHTTPRequest(for: request.provider, apiKey: apiKey, baseURL: request.baseURL)
        let response: TranscriptTranslationHTTPResponse
        do {
            response = try await transport.send(httpRequest)
        } catch {
            throw ProviderAPIKeyTestError.client(provider: request.provider)
        }

        try validate(response: response, provider: request.provider)
        try parseSuccessResponse(response.body, provider: request.provider)
    }

    private func makeHTTPRequest(
        for provider: TranscriptTranslationProvider,
        apiKey: String,
        baseURL: URL
    ) throws -> TranscriptTranslationHTTPRequest {
        switch provider {
        case .gemini:
            return TranscriptTranslationHTTPRequest(
                method: "GET",
                url: try keyedURL(Self.geminiModelsURL(from: baseURL), apiKey: apiKey, provider: provider),
                headers: [:],
                body: Data()
            )
        case .openAI:
            return TranscriptTranslationHTTPRequest(
                method: "GET",
                url: Self.openAIModelsURL(from: baseURL),
                headers: ["Authorization": "Bearer \(apiKey)"],
                body: Data()
            )
        case .googleTranslate:
            return TranscriptTranslationHTTPRequest(
                method: "GET",
                url: try keyedURL(Self.googleTranslateLanguagesURL(from: baseURL), apiKey: apiKey, provider: provider),
                headers: [:],
                body: Data()
            )
        }
    }

    private func validate(response: TranscriptTranslationHTTPResponse, provider: TranscriptTranslationProvider) throws {
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 {
                throw ProviderAPIKeyTestError.authentication(provider: provider, statusCode: response.statusCode)
            }

            throw ProviderAPIKeyTestError.provider(provider: provider, statusCode: response.statusCode)
        }
    }

    private func parseSuccessResponse(_ data: Data, provider: TranscriptTranslationProvider) throws {
        do {
            switch provider {
            case .gemini:
                let envelope = try decoder.decode(GeminiModelsEnvelope.self, from: data)
                guard !envelope.models.isEmpty else {
                    throw ProviderAPIKeyTestError.malformedResponse(provider: provider)
                }
            case .openAI:
                let envelope = try decoder.decode(OpenAIModelsEnvelope.self, from: data)
                guard envelope.object == "list" else {
                    throw ProviderAPIKeyTestError.malformedResponse(provider: provider)
                }
            case .googleTranslate:
                let envelope = try decoder.decode(GoogleTranslateLanguagesEnvelope.self, from: data)
                guard !envelope.data.languages.isEmpty else {
                    throw ProviderAPIKeyTestError.malformedResponse(provider: provider)
                }
            }
        } catch let error as ProviderAPIKeyTestError {
            throw error
        } catch {
            throw ProviderAPIKeyTestError.malformedResponse(provider: provider)
        }
    }

    private func keyedURL(_ url: URL, apiKey: String, provider: TranscriptTranslationProvider) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ProviderAPIKeyTestError.client(provider: provider)
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        components.queryItems = queryItems

        guard let keyedURL = components.url else {
            throw ProviderAPIKeyTestError.client(provider: provider)
        }

        return keyedURL
    }

    private static func geminiModelsURL(from baseURL: URL) -> URL {
        let path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("v1beta/models") {
            return baseURL
        }

        if path.hasSuffix("v1beta") {
            return baseURL.appendingPathComponent("models")
        }

        return baseURL
            .appendingPathComponent("v1beta")
            .appendingPathComponent("models")
    }

    private static func openAIModelsURL(from baseURL: URL) -> URL {
        let path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("models") {
            return baseURL
        }

        if path.hasSuffix("v1") {
            return baseURL.appendingPathComponent("models")
        }

        return baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("models")
    }

    private static func googleTranslateLanguagesURL(from baseURL: URL) -> URL {
        let path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("language/translate/v2/languages") {
            return baseURL
        }

        if path.hasSuffix("language/translate/v2") {
            return baseURL.appendingPathComponent("languages")
        }

        return baseURL
            .appendingPathComponent("language")
            .appendingPathComponent("translate")
            .appendingPathComponent("v2")
            .appendingPathComponent("languages")
    }
}

struct TranscriptTranslationService: TranscriptTranslating {
    private let geminiAPIKeyStore: any GeminiAPIKeyStoring
    private let openAIAPIKeyStore: any OpenAIAPIKeyStoring
    private let googleTranslateAPIKeyStore: any GoogleTranslateAPIKeyStoring
    private let transport: any TranscriptTranslationHTTPTransport
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    static func previewPrompt(
        context: TranscriptTranslationContext,
        sourceLanguage: String = "Source language",
        targetLanguage: String = "Output language"
    ) -> String {
        (try? prompt(
            text: "[meeting transcript text]",
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            context: context
        )) ?? "Custom prompt is missing required placeholders: \(TranscriptPromptTemplate.requiredPlaceholders.joined(separator: ", "))."
    }

    init(
        geminiAPIKeyStore: any GeminiAPIKeyStoring = KeychainGeminiAPIKeyStore(),
        openAIAPIKeyStore: any OpenAIAPIKeyStoring = KeychainOpenAIAPIKeyStore(),
        googleTranslateAPIKeyStore: any GoogleTranslateAPIKeyStoring = KeychainGoogleTranslateAPIKeyStore(),
        transport: any TranscriptTranslationHTTPTransport = URLSessionTranscriptTranslationHTTPTransport()
    ) {
        self.geminiAPIKeyStore = geminiAPIKeyStore
        self.openAIAPIKeyStore = openAIAPIKeyStore
        self.googleTranslateAPIKeyStore = googleTranslateAPIKeyStore
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
        case .googleTranslate:
            return try await translateWithGoogleTranslate(request, text: trimmedText)
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
                            text: try Self.prompt(
                                text: text,
                                sourceLanguage: request.sourceLanguage.displayName,
                                targetLanguage: request.targetLanguage.displayName,
                                context: request.context
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
                    content: try Self.prompt(
                        text: text,
                        sourceLanguage: request.sourceLanguage.displayName,
                        targetLanguage: request.targetLanguage.displayName,
                        context: request.context
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

    private func translateWithGoogleTranslate(
        _ request: TranscriptTranslationRequest,
        text: String
    ) async throws -> String {
        let apiKey = try loadAPIKey(
            provider: .googleTranslate,
            loader: googleTranslateAPIKeyStore.loadAPIKey
        )
        let url = try googleTranslateURL(
            from: request.providerConfig.baseURL,
            text: text,
            sourceLanguage: request.sourceLanguage.isAutoDetect ? nil : request.sourceLanguage.whisperCode,
            targetLanguage: request.targetLanguage.rawValue,
            apiKey: apiKey
        )
        let response = try await transport.send(
            TranscriptTranslationHTTPRequest(
                method: "POST",
                url: url,
                headers: [:],
                body: Data()
            )
        )
        try validate(response: response, provider: .googleTranslate)
        return try parseGoogleTranslateText(response.body)
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

    private func parseGoogleTranslateText(_ data: Data) throws -> String {
        do {
            let envelope = try decoder.decode(GoogleTranslateEnvelope.self, from: data)
            let text = envelope.data.translations
                .map(\.translatedText)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            guard let text else {
                throw TranscriptTranslationError.malformedResponse(provider: .googleTranslate)
            }

            return text
        } catch let error as TranscriptTranslationError {
            throw error
        } catch {
            throw TranscriptTranslationError.malformedResponse(provider: .googleTranslate)
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

    private func googleTranslateURL(
        from baseURL: URL,
        text: String,
        sourceLanguage: String?,
        targetLanguage: String,
        apiKey: String
    ) throws -> URL {
        let baseTranslateURL = Self.googleTranslateEndpointURL(from: baseURL)
        guard var components = URLComponents(url: baseTranslateURL, resolvingAgainstBaseURL: false) else {
            throw TranscriptTranslationError.invalidRequest
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "target", value: targetLanguage),
            URLQueryItem(name: "format", value: "text"),
            URLQueryItem(name: "key", value: apiKey)
        ])
        if let sourceLanguage {
            queryItems.insert(URLQueryItem(name: "source", value: sourceLanguage), at: 1)
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw TranscriptTranslationError.invalidRequest
        }

        return url
    }

    private static func googleTranslateEndpointURL(from baseURL: URL) -> URL {
        let path = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("language/translate/v2") {
            return baseURL
        }

        return baseURL
            .appendingPathComponent("language")
            .appendingPathComponent("translate")
            .appendingPathComponent("v2")
    }

    private static func prompt(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        context: TranscriptTranslationContext
    ) throws -> String {
        if context.domain == .customPrompt {
            guard let renderedPrompt = TranscriptPromptTemplate.render(
                template: TranscriptPromptTemplate.normalizedTemplate(context.customPromptTemplate),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                transcript: text
            ) else {
                throw TranscriptTranslationError.invalidRequest
            }

            return renderedPrompt
        }

        var promptLines = [
            "Translate this meeting transcript window from \(sourceLanguage) to \(targetLanguage).",
            "Return only the translated text. Preserve speaker meaning, numbers, names, and punctuation. Do not summarize, explain, add labels, or include the original text.",
            "Translation context: \(context.domain.displayName). \(context.domain.promptInstruction)"
        ]
        promptLines.append("")
        promptLines.append("Transcript:")
        promptLines.append(text)
        return promptLines.joined(separator: "\n")
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

private struct GoogleTranslateEnvelope: Decodable {
    let data: GoogleTranslateData
}

private struct GoogleTranslateData: Decodable {
    let translations: [GoogleTranslateResult]
}

private struct GoogleTranslateResult: Decodable {
    let translatedText: String
}

private struct GeminiModelsEnvelope: Decodable {
    let models: [GeminiModelEnvelope]
}

private struct GeminiModelEnvelope: Decodable {
    let name: String?
}

private struct OpenAIModelsEnvelope: Decodable {
    let object: String
    let data: [OpenAIModelEnvelope]
}

private struct OpenAIModelEnvelope: Decodable {
    let id: String?
}

private struct GoogleTranslateLanguagesEnvelope: Decodable {
    let data: GoogleTranslateLanguagesData
}

private struct GoogleTranslateLanguagesData: Decodable {
    let languages: [GoogleTranslateLanguageEnvelope]
}

private struct GoogleTranslateLanguageEnvelope: Decodable {
    let language: String?
}
