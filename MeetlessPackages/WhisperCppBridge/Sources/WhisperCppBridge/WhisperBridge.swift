import Foundation
import whisper

enum WhisperBridgeError: LocalizedError {
    case missingBundledResource(name: String, ext: String)
    case failedToInitializeModel(path: String)
    case noLoadedModel(source: RecordingSourceKind)
    case transcriptionFailed(code: Int32)
    case emptyTranscription

    var errorDescription: String? {
        switch self {
        case let .missingBundledResource(name, ext):
            return "Missing bundled resource \(name).\(ext)."
        case let .failedToInitializeModel(path):
            return "Failed to initialize whisper from \(path)."
        case let .noLoadedModel(source):
            return "No whisper model is loaded for the \(source.rawValue) worker."
        case let .transcriptionFailed(code):
            return "whisper_full failed with status \(code)."
        case .emptyTranscription:
            return "Whisper returned an empty transcription."
        }
    }
}

struct TranscriptionLanguage: RawRepresentable, CaseIterable, Identifiable, Codable, Sendable, Equatable, Hashable {
    let rawValue: String
    let displayName: String

    var id: String { rawValue }
    var whisperCode: String { rawValue }
    var isAutoDetect: Bool { rawValue == Self.autoDetect.rawValue }

    static let autoDetect = TranscriptionLanguage(rawValue: "auto", displayName: "Auto Detect")
    static let english = TranscriptionLanguage(rawValue: "en", displayName: "English")
    static let korean = TranscriptionLanguage(rawValue: "ko", displayName: "Korean")
    static let vietnamese = TranscriptionLanguage(rawValue: "vi", displayName: "Vietnamese")
    static let defaultLanguage: TranscriptionLanguage = .english

    static let allCases: [TranscriptionLanguage] = [.autoDetect] + supportedLanguages.sorted {
        $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
    }

    private static let supportedLanguages: [TranscriptionLanguage] = [
        .english,
        TranscriptionLanguage(rawValue: "zh", displayName: "Chinese"),
        TranscriptionLanguage(rawValue: "de", displayName: "German"),
        TranscriptionLanguage(rawValue: "es", displayName: "Spanish"),
        TranscriptionLanguage(rawValue: "ru", displayName: "Russian"),
        .korean,
        TranscriptionLanguage(rawValue: "fr", displayName: "French"),
        TranscriptionLanguage(rawValue: "ja", displayName: "Japanese"),
        TranscriptionLanguage(rawValue: "pt", displayName: "Portuguese"),
        TranscriptionLanguage(rawValue: "tr", displayName: "Turkish"),
        TranscriptionLanguage(rawValue: "pl", displayName: "Polish"),
        TranscriptionLanguage(rawValue: "ca", displayName: "Catalan"),
        TranscriptionLanguage(rawValue: "nl", displayName: "Dutch"),
        TranscriptionLanguage(rawValue: "ar", displayName: "Arabic"),
        TranscriptionLanguage(rawValue: "sv", displayName: "Swedish"),
        TranscriptionLanguage(rawValue: "it", displayName: "Italian"),
        TranscriptionLanguage(rawValue: "id", displayName: "Indonesian"),
        TranscriptionLanguage(rawValue: "hi", displayName: "Hindi"),
        TranscriptionLanguage(rawValue: "fi", displayName: "Finnish"),
        .vietnamese,
        TranscriptionLanguage(rawValue: "he", displayName: "Hebrew"),
        TranscriptionLanguage(rawValue: "uk", displayName: "Ukrainian"),
        TranscriptionLanguage(rawValue: "el", displayName: "Greek"),
        TranscriptionLanguage(rawValue: "ms", displayName: "Malay"),
        TranscriptionLanguage(rawValue: "cs", displayName: "Czech"),
        TranscriptionLanguage(rawValue: "ro", displayName: "Romanian"),
        TranscriptionLanguage(rawValue: "da", displayName: "Danish"),
        TranscriptionLanguage(rawValue: "hu", displayName: "Hungarian"),
        TranscriptionLanguage(rawValue: "ta", displayName: "Tamil"),
        TranscriptionLanguage(rawValue: "no", displayName: "Norwegian"),
        TranscriptionLanguage(rawValue: "th", displayName: "Thai"),
        TranscriptionLanguage(rawValue: "ur", displayName: "Urdu"),
        TranscriptionLanguage(rawValue: "hr", displayName: "Croatian"),
        TranscriptionLanguage(rawValue: "bg", displayName: "Bulgarian"),
        TranscriptionLanguage(rawValue: "lt", displayName: "Lithuanian"),
        TranscriptionLanguage(rawValue: "la", displayName: "Latin"),
        TranscriptionLanguage(rawValue: "mi", displayName: "Maori"),
        TranscriptionLanguage(rawValue: "ml", displayName: "Malayalam"),
        TranscriptionLanguage(rawValue: "cy", displayName: "Welsh"),
        TranscriptionLanguage(rawValue: "sk", displayName: "Slovak"),
        TranscriptionLanguage(rawValue: "te", displayName: "Telugu"),
        TranscriptionLanguage(rawValue: "fa", displayName: "Persian"),
        TranscriptionLanguage(rawValue: "lv", displayName: "Latvian"),
        TranscriptionLanguage(rawValue: "bn", displayName: "Bengali"),
        TranscriptionLanguage(rawValue: "sr", displayName: "Serbian"),
        TranscriptionLanguage(rawValue: "az", displayName: "Azerbaijani"),
        TranscriptionLanguage(rawValue: "sl", displayName: "Slovenian"),
        TranscriptionLanguage(rawValue: "kn", displayName: "Kannada"),
        TranscriptionLanguage(rawValue: "et", displayName: "Estonian"),
        TranscriptionLanguage(rawValue: "mk", displayName: "Macedonian"),
        TranscriptionLanguage(rawValue: "br", displayName: "Breton"),
        TranscriptionLanguage(rawValue: "eu", displayName: "Basque"),
        TranscriptionLanguage(rawValue: "is", displayName: "Icelandic"),
        TranscriptionLanguage(rawValue: "hy", displayName: "Armenian"),
        TranscriptionLanguage(rawValue: "ne", displayName: "Nepali"),
        TranscriptionLanguage(rawValue: "mn", displayName: "Mongolian"),
        TranscriptionLanguage(rawValue: "bs", displayName: "Bosnian"),
        TranscriptionLanguage(rawValue: "kk", displayName: "Kazakh"),
        TranscriptionLanguage(rawValue: "sq", displayName: "Albanian"),
        TranscriptionLanguage(rawValue: "sw", displayName: "Swahili"),
        TranscriptionLanguage(rawValue: "gl", displayName: "Galician"),
        TranscriptionLanguage(rawValue: "mr", displayName: "Marathi"),
        TranscriptionLanguage(rawValue: "pa", displayName: "Punjabi"),
        TranscriptionLanguage(rawValue: "si", displayName: "Sinhala"),
        TranscriptionLanguage(rawValue: "km", displayName: "Khmer"),
        TranscriptionLanguage(rawValue: "sn", displayName: "Shona"),
        TranscriptionLanguage(rawValue: "yo", displayName: "Yoruba"),
        TranscriptionLanguage(rawValue: "so", displayName: "Somali"),
        TranscriptionLanguage(rawValue: "af", displayName: "Afrikaans"),
        TranscriptionLanguage(rawValue: "oc", displayName: "Occitan"),
        TranscriptionLanguage(rawValue: "ka", displayName: "Georgian"),
        TranscriptionLanguage(rawValue: "be", displayName: "Belarusian"),
        TranscriptionLanguage(rawValue: "tg", displayName: "Tajik"),
        TranscriptionLanguage(rawValue: "sd", displayName: "Sindhi"),
        TranscriptionLanguage(rawValue: "gu", displayName: "Gujarati"),
        TranscriptionLanguage(rawValue: "am", displayName: "Amharic"),
        TranscriptionLanguage(rawValue: "yi", displayName: "Yiddish"),
        TranscriptionLanguage(rawValue: "lo", displayName: "Lao"),
        TranscriptionLanguage(rawValue: "uz", displayName: "Uzbek"),
        TranscriptionLanguage(rawValue: "fo", displayName: "Faroese"),
        TranscriptionLanguage(rawValue: "ht", displayName: "Haitian Creole"),
        TranscriptionLanguage(rawValue: "ps", displayName: "Pashto"),
        TranscriptionLanguage(rawValue: "tk", displayName: "Turkmen"),
        TranscriptionLanguage(rawValue: "nn", displayName: "Nynorsk"),
        TranscriptionLanguage(rawValue: "mt", displayName: "Maltese"),
        TranscriptionLanguage(rawValue: "sa", displayName: "Sanskrit"),
        TranscriptionLanguage(rawValue: "lb", displayName: "Luxembourgish"),
        TranscriptionLanguage(rawValue: "my", displayName: "Myanmar"),
        TranscriptionLanguage(rawValue: "bo", displayName: "Tibetan"),
        TranscriptionLanguage(rawValue: "tl", displayName: "Tagalog"),
        TranscriptionLanguage(rawValue: "mg", displayName: "Malagasy"),
        TranscriptionLanguage(rawValue: "as", displayName: "Assamese"),
        TranscriptionLanguage(rawValue: "tt", displayName: "Tatar"),
        TranscriptionLanguage(rawValue: "haw", displayName: "Hawaiian"),
        TranscriptionLanguage(rawValue: "ln", displayName: "Lingala"),
        TranscriptionLanguage(rawValue: "ha", displayName: "Hausa"),
        TranscriptionLanguage(rawValue: "ba", displayName: "Bashkir"),
        TranscriptionLanguage(rawValue: "jw", displayName: "Javanese"),
        TranscriptionLanguage(rawValue: "su", displayName: "Sundanese"),
        TranscriptionLanguage(rawValue: "yue", displayName: "Cantonese")
    ]

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
}

struct WhisperBridgeAssets {
    let bundle: Bundle
    let modelBasename: String
    let modelExtension: String
    let sampleBasename: String
    let sampleExtension: String

    init(
        bundle: Bundle = .main,
        modelBasename: String = "ggml-base",
        modelExtension: String = "bin",
        sampleBasename: String = "jfk",
        sampleExtension: String = "wav"
    ) {
        self.bundle = bundle
        self.modelBasename = modelBasename
        self.modelExtension = modelExtension
        self.sampleBasename = sampleBasename
        self.sampleExtension = sampleExtension
    }

    func bundledModelURL() throws -> URL {
        guard let url = bundle.url(forResource: modelBasename, withExtension: modelExtension) else {
            throw WhisperBridgeError.missingBundledResource(name: modelBasename, ext: modelExtension)
        }
        return url
    }

    func bundledSmokeSampleURL() throws -> URL {
        guard let url = bundle.url(forResource: sampleBasename, withExtension: sampleExtension) else {
            throw WhisperBridgeError.missingBundledResource(name: sampleBasename, ext: sampleExtension)
        }
        return url
    }

    var bundledModelFilename: String {
        "\(modelBasename).\(modelExtension)"
    }

    var bundledSampleFilename: String {
        "\(sampleBasename).\(sampleExtension)"
    }
}

struct WhisperSmokeTranscription {
    let source: RecordingSourceKind
    let modelName: String
    let sampleName: String
    let text: String
    let sampleCount: Int
    let threadCount: Int
}

final class WhisperContextHandle {
    let opaquePointer: OpaquePointer

    init(opaquePointer: OpaquePointer) {
        self.opaquePointer = opaquePointer
    }

    deinit {
        whisper_free(opaquePointer)
    }
}
