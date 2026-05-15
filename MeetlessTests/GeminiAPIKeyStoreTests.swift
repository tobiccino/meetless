import Security
import XCTest
@testable import Meetless

final class GeminiAPIKeyStoreTests: XCTestCase {
    func testTranscriptionSettingsDefaultLanguageIsEnglish() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(store.transcriptionLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage.whisperCode, "en")
        XCTAssertEqual(store.transcriptOutputLanguage, .english)
        XCTAssertEqual(store.transcriptTranslationProvider, .gemini)
        XCTAssertEqual(store.translationModel(for: .gemini), "gemini-2.5-flash")
        XCTAssertEqual(store.translationModel(for: .openAI), "gpt-5.4-mini")
    }

    func testTranscriptionSettingsPersistsKoreanLanguage() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        store.transcriptionLanguage = .korean

        let reopenedStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reopenedStore.transcriptionLanguage, .korean)
        XCTAssertEqual(reopenedStore.transcriptionLanguage.whisperCode, "ko")
    }

    func testTranscriptionSettingsFallsBackToEnglishForInvalidStoredValue() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        userDefaults.set("fr", forKey: "meetless.transcriptionLanguage")
        userDefaults.set("fr", forKey: "meetless.transcriptOutputLanguage")
        userDefaults.set("anthropic", forKey: "meetless.transcriptTranslationProvider")
        userDefaults.set("", forKey: "meetless.transcriptTranslation.gemini.model")
        userDefaults.set("not a url", forKey: "meetless.transcriptTranslation.openai.baseURL")
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(store.transcriptionLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage.whisperCode, "en")
        XCTAssertEqual(store.transcriptOutputLanguage, .english)
        XCTAssertEqual(store.transcriptTranslationProvider, .gemini)
        XCTAssertEqual(store.translationModel(for: .gemini), "gemini-2.5-flash")
        XCTAssertEqual(store.translationBaseURL(for: .openAI).absoluteString, "https://api.openai.com")
    }

    func testTranscriptionSettingsPersistsVietnameseOutputAndOpenAIProviderPreset() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        store.transcriptOutputLanguage = .vietnamese
        store.transcriptTranslationProvider = .openAI
        store.setTranslationModel("gpt-test-translation", for: .openAI)
        store.setTranslationBaseURL(URL(string: "https://openai.test")!, for: .openAI)

        let reopenedStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reopenedStore.transcriptOutputLanguage, .vietnamese)
        XCTAssertEqual(reopenedStore.transcriptTranslationProvider, .openAI)
        XCTAssertEqual(reopenedStore.translationModel(for: .openAI), "gpt-test-translation")
        XCTAssertEqual(reopenedStore.translationBaseURL(for: .openAI).absoluteString, "https://openai.test")
    }

    func testWhisperBridgeDefaultsToMultilingualBaseModel() {
        let assets = WhisperBridgeAssets(bundle: Bundle(for: Self.self))

        XCTAssertEqual(assets.modelBasename, "ggml-base")
        XCTAssertEqual(assets.bundledModelFilename, "ggml-base.bin")
    }

    func testTranscriptionLanguageMapsKoreanToWhisperCode() {
        XCTAssertEqual(TranscriptionLanguage.korean.whisperCode, "ko")
    }

    func testLoadAPIKeyReturnsNilWhenKeyIsMissing() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        let apiKey = try store.loadAPIKey()

        XCTAssertNil(apiKey)
    }

    func testSaveAPIKeyStoresValueForLaterReads() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("gemini-secret")

        XCTAssertEqual(try store.loadAPIKey(), "gemini-secret")
        XCTAssertEqual(keychain.recordedValues, ["gemini-secret"])
    }

    func testOpenAIKeychainStoreUsesSeparateKeychainPath() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainOpenAIAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("openai-secret")

        XCTAssertEqual(try store.loadAPIKey(), "openai-secret")
        XCTAssertEqual(keychain.recordedValues, ["openai-secret"])
    }

    func testSaveAPIKeyUpdatesExistingValue() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("old-secret")
        try store.saveAPIKey("new-secret")

        XCTAssertEqual(try store.loadAPIKey(), "new-secret")
        XCTAssertEqual(keychain.recordedValues, ["old-secret", "new-secret"])
    }

    func testDeleteAPIKeyRemovesValueForLaterReads() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("gemini-secret")
        try store.deleteAPIKey()

        XCTAssertNil(try store.loadAPIKey())
    }

    func testDeleteAPIKeySucceedsWhenValueIsAlreadyMissing() {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertNoThrow(try store.deleteAPIKey())
    }

    func testLoadMapsKeychainFailure() {
        let keychain = FakeKeychainItemAccessor(copyMatchingStatusOverride: errSecAuthFailed)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.loadAPIKey()) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .copyMatching, status: errSecAuthFailed)
            )
        }
    }

    func testSaveMapsAddFailure() {
        let keychain = FakeKeychainItemAccessor(addStatusOverride: errSecNotAvailable)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.saveAPIKey("gemini-secret")) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .add, status: errSecNotAvailable)
            )
        }
    }

    func testSaveMapsUpdateFailure() {
        let keychain = FakeKeychainItemAccessor(updateStatusOverride: errSecInteractionNotAllowed)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertNoThrow(try store.saveAPIKey("old-secret"))
        XCTAssertThrowsError(try store.saveAPIKey("new-secret")) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .update, status: errSecInteractionNotAllowed)
            )
        }
    }

    func testDeleteMapsFailure() {
        let keychain = FakeKeychainItemAccessor(deleteStatusOverride: errSecAuthFailed)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.deleteAPIKey()) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .delete, status: errSecAuthFailed)
            )
        }
    }

    func testLoadMapsInvalidStoredData() {
        let keychain = FakeKeychainItemAccessor(copyMatchingItemOverride: "not-data")
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.loadAPIKey()) { error in
            XCTAssertEqual(error as? GeminiAPIKeyStoreError, .invalidStoredData)
        }
    }

    @MainActor
    func testSettingsViewModelShowsNotConfiguredWhenKeyIsMissing() {
        let store = KeychainGeminiAPIKeyStore(keychain: FakeKeychainItemAccessor())
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        XCTAssertEqual(viewModel.keyStatus, .notConfigured)
        XCTAssertFalse(viewModel.isConfigured)
    }

    @MainActor
    func testSettingsViewModelSavesTrimmedKeyWithoutDisplayingSecret() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        viewModel.apiKeyInput = "  gemini-secret  "
        viewModel.saveAPIKey()

        XCTAssertEqual(try store.loadAPIKey(), "gemini-secret")
        XCTAssertEqual(keychain.recordedValues, ["gemini-secret"])
        XCTAssertEqual(viewModel.keyStatus, .configured)
        XCTAssertEqual(viewModel.apiKeyInput, "")
        XCTAssertFalse(viewModel.keyStatus.detail.contains("gemini-secret"))
        XCTAssertFalse(viewModel.feedbackMessage?.contains("gemini-secret") ?? false)
    }

    @MainActor
    func testSettingsViewModelRejectsBlankKey() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        viewModel.apiKeyInput = "   "
        viewModel.saveAPIKey()

        XCTAssertNil(try store.loadAPIKey())
        XCTAssertEqual(viewModel.keyStatus, .notConfigured)
        XCTAssertEqual(viewModel.feedbackMessage, "Enter a Gemini API key before saving.")
    }

    @MainActor
    func testSettingsViewModelDeletesSavedKey() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)
        try store.saveAPIKey("gemini-secret")
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        viewModel.deleteAPIKey()

        XCTAssertNil(try store.loadAPIKey())
        XCTAssertEqual(viewModel.keyStatus, .notConfigured)
        XCTAssertEqual(viewModel.feedbackMessage, "Gemini API key removed.")
    }

    @MainActor
    func testSettingsViewModelMapsKeychainErrorsToSafeCopy() {
        let store = KeychainGeminiAPIKeyStore(
            keychain: FakeKeychainItemAccessor(copyMatchingStatusOverride: errSecAuthFailed)
        )
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        XCTAssertEqual(
            viewModel.keyStatus,
            .error("Keychain could not complete the request. Check macOS access and try again.")
        )
    }
}

private func makeIsolatedUserDefaults() throws -> UserDefaults {
    let suiteName = "MeetlessTests-\(UUID().uuidString)"
    let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
}

private final class FakeKeychainItemAccessor: KeychainItemAccessing {
    private var storedData: Data?
    private let addStatusOverride: OSStatus?
    private let copyMatchingStatusOverride: OSStatus?
    private let copyMatchingItemOverride: Any?
    private let updateStatusOverride: OSStatus?
    private let deleteStatusOverride: OSStatus?

    private(set) var recordedValues: [String] = []

    init(
        addStatusOverride: OSStatus? = nil,
        copyMatchingStatusOverride: OSStatus? = nil,
        copyMatchingItemOverride: Any? = nil,
        updateStatusOverride: OSStatus? = nil,
        deleteStatusOverride: OSStatus? = nil
    ) {
        self.addStatusOverride = addStatusOverride
        self.copyMatchingStatusOverride = copyMatchingStatusOverride
        self.copyMatchingItemOverride = copyMatchingItemOverride
        self.updateStatusOverride = updateStatusOverride
        self.deleteStatusOverride = deleteStatusOverride
    }

    func add(_ query: [String: Any]) -> OSStatus {
        if let addStatusOverride {
            return addStatusOverride
        }

        guard storedData == nil else {
            return errSecDuplicateItem
        }

        storedData = query[kSecValueData as String] as? Data
        recordStoredValue()
        return errSecSuccess
    }

    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, item: Any?) {
        if let copyMatchingStatusOverride {
            return (copyMatchingStatusOverride, nil)
        }

        if let copyMatchingItemOverride {
            return (errSecSuccess, copyMatchingItemOverride)
        }

        guard let storedData else {
            return (errSecItemNotFound, nil)
        }

        return (errSecSuccess, storedData)
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        if let updateStatusOverride {
            return updateStatusOverride
        }

        guard storedData != nil else {
            return errSecItemNotFound
        }

        storedData = attributes[kSecValueData as String] as? Data
        recordStoredValue()
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        if let deleteStatusOverride {
            return deleteStatusOverride
        }

        guard storedData != nil else {
            return errSecItemNotFound
        }

        storedData = nil
        return errSecSuccess
    }

    private func recordStoredValue() {
        guard let storedData, let value = String(data: storedData, encoding: .utf8) else {
            return
        }

        recordedValues.append(value)
    }
}
