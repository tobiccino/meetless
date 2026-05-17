import SwiftUI

struct MeetlessRootView: View {
    @StateObject private var appModel = AppModel()

    var body: some View {
        MeetlessShellView(
            selectedScreen: appModel.selectedScreen,
            onSelectScreen: { screen in appModel.show(screen) }
        ) {
            currentScreen
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch appModel.selectedScreen {
        case .home:
            HomeView(
                viewModel: appModel.homeViewModel,
                recordingViewModel: appModel.recordingViewModel,
                onOpenHistory: { appModel.show(.history) },
                onOpenSessionDetail: { appModel.show(.sessionDetail) }
            )
        case .history:
            HistoryView(
                viewModel: appModel.historyViewModel,
                onBackHome: { appModel.show(.home) },
                onReload: { Task { await appModel.refreshSavedSessions() } },
                onOpenSessionDetail: { row in appModel.openSessionDetail(for: row) },
                onDeleteSession: { row in appModel.deleteSession(row) }
            )
        case .sessionDetail:
            SessionDetailView(
                viewModel: appModel.sessionDetailViewModel,
                onBackToHistory: { appModel.show(.history) },
                onDeleteSession: { appModel.deleteSelectedSession() },
                onGenerateNotes: { appModel.generateNotesForSelectedSession() }
            )
        case .settings:
            SettingsView(viewModel: appModel.geminiSettingsViewModel)
        }
    }
}

private struct MeetlessShellView<Content: View>: View {
    let selectedScreen: AppScreen
    let onSelectScreen: (AppScreen) -> Void
    let content: Content

    init(
        selectedScreen: AppScreen,
        onSelectScreen: @escaping (AppScreen) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.selectedScreen = selectedScreen
        self.onSelectScreen = onSelectScreen
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarNavigation(
                selectedScreen: selectedScreen,
                onSelectScreen: onSelectScreen
            )

            HairlineDivider(.vertical)

            VStack(spacing: 0) {
                toolbar

                HairlineDivider()

                MeetlessCanvas {
                    content
                }
            }
        }
        .background(MeetlessDesignTokens.Colors.appBackground)
    }

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedScreen.title)
                    .font(MeetlessDesignTokens.Typography.windowTitle)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text(selectedScreen.subtitle)
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, MeetlessDesignTokens.Layout.contentPadding)
        .frame(height: MeetlessDesignTokens.Layout.toolbarHeight)
        .background(MeetlessDesignTokens.Colors.windowBackground)
    }
}

private struct SidebarNavigation: View {
    let selectedScreen: AppScreen
    let onSelectScreen: (AppScreen) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meetless")
                    .font(MeetlessDesignTokens.Typography.windowTitle)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text("Local recorder")
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 18)

            VStack(spacing: 4) {
                ForEach(AppScreen.primaryNavigationCases) { screen in
                    Button {
                        onSelectScreen(screen)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: screen.systemImage)
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 20)
                            Text(screen.title)
                                .font(MeetlessDesignTokens.Typography.body.weight(.medium))
                                .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            Spacer()
                        }
                        .foregroundStyle(
                            selectedScreen == screen
                                ? MeetlessDesignTokens.Colors.primaryBlue
                                : MeetlessDesignTokens.Colors.secondaryText
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.selection, style: .continuous)
                                .fill(selectedScreen == screen ? MeetlessDesignTokens.Colors.sidebarSelection : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(screen.title)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            LocalStatusFooter()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: MeetlessDesignTokens.Layout.sidebarWidth)
        .background(MeetlessDesignTokens.Colors.sidebarBackground)
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: GeminiSettingsViewModel
    @State private var isConfirmingDelete = false
    @State private var isConfirmingOpenAIDelete = false
    @State private var isConfirmingGoogleTranslateDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetlessDesignTokens.Layout.largeGap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(MeetlessDesignTokens.Typography.screenTitle)
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                    Text("Choose transcript languages and manage provider access.")
                        .font(MeetlessDesignTokens.Typography.body)
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                }

                transcriptionCard

                translationCard

                VStack(alignment: .leading, spacing: MeetlessDesignTokens.Layout.defaultGap) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gemini")
                            .font(MeetlessDesignTokens.Typography.windowTitle)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                        Text("Save the API key used for Gemini session notes and Gemini transcript translation.")
                            .font(MeetlessDesignTokens.Typography.caption)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                    }

                    GeminiKeyStatusRow(
                        status: viewModel.keyStatus,
                        providerName: "Gemini",
                        missingMessage: "Add a Gemini API key before generating notes or translating with Gemini."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("API key")
                            .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                        SecureField(
                            viewModel.isConfigured ? "Enter a new key to update" : "Enter Gemini API key",
                            text: $viewModel.apiKeyInput
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(MeetlessDesignTokens.Typography.body)

                        Text("Saved keys stay in macOS Keychain and are not shown again after saving.")
                            .font(MeetlessDesignTokens.Typography.caption)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                    }

                    HStack(spacing: 10) {
                        Button {
                            viewModel.saveAPIKey()
                        } label: {
                            Label(viewModel.isConfigured ? "Update Key" : "Save Key", systemImage: "key.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canSave)

                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("Delete Key", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!viewModel.isConfigured)

                        Spacer()
                    }
                }
                .padding(18)
                .background(MeetlessDesignTokens.Colors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                        .stroke(MeetlessDesignTokens.Colors.separator)
                )

                openAICard

                googleTranslateCard

                if let feedbackMessage = viewModel.feedbackMessage {
                    Text(feedbackMessage)
                        .font(MeetlessDesignTokens.Typography.caption.weight(.medium))
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: MeetlessDesignTokens.Layout.contentMaxWidth, alignment: .leading)
            .padding(.vertical, 6)
        }
        .alert("Delete Gemini API key?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                viewModel.deleteAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Session notes generation will stay unavailable until a new key is saved.")
        }
        .alert("Delete OpenAI API key?", isPresented: $isConfirmingOpenAIDelete) {
            Button("Delete", role: .destructive) {
                viewModel.deleteOpenAIAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("OpenAI transcript translation will stay unavailable until a new key is saved.")
        }
        .alert("Delete Google Translate API key?", isPresented: $isConfirmingGoogleTranslateDelete) {
            Button("Delete", role: .destructive) {
                viewModel.deleteGoogleTranslateAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Google Translate transcript translation will stay unavailable until a new key is saved.")
        }
    }

    private var transcriptionCard: some View {
        VStack(alignment: .leading, spacing: MeetlessDesignTokens.Layout.defaultGap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Transcription")
                    .font(MeetlessDesignTokens.Typography.windowTitle)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text("Applies to the next recording and smoke transcription run.")
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }

            Picker("Language", selection: $viewModel.transcriptionLanguage) {
                ForEach(TranscriptionLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320)

            VStack(alignment: .leading, spacing: 10) {
                Text("Whisper model")
                    .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                ForEach(viewModel.transcriptionModelStatuses) { status in
                    transcriptionModelRow(status)
                }
            }
        }
        .padding(18)
        .background(MeetlessDesignTokens.Colors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                .stroke(MeetlessDesignTokens.Colors.separator)
        )
    }

    private func transcriptionModelRow(_ status: TranscriptionModelStatus) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.selectTranscriptionModel(status.id)
            } label: {
                Image(systemName: status.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(status.isSelected ? MeetlessDesignTokens.Colors.primaryBlue : MeetlessDesignTokens.Colors.tertiaryText)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(!status.canSelect)
            .accessibilityLabel("Select \(status.preset.displayName)")

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(status.preset.displayName)
                        .font(MeetlessDesignTokens.Typography.body.weight(.semibold))
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(status.canSelect ? MeetlessDesignTokens.Colors.primaryText : MeetlessDesignTokens.Colors.secondaryText)

                    Text(status.preset.qualityLabel)
                        .font(MeetlessDesignTokens.Typography.caption)
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    transcriptionModelDetailLine(
                        systemImage: "internaldrive",
                        label: "Storage",
                        value: status.preset.diskSizeLabel
                    )
                    transcriptionModelDetailLine(
                        systemImage: "memorychip",
                        label: "CPU/RAM",
                        value: status.preset.resourceLabel
                    )
                    transcriptionModelDetailLine(
                        systemImage: "globe",
                        label: "Language",
                        value: status.preset.languageLabel
                    )
                    transcriptionModelDetailLine(
                        systemImage: "scope",
                        label: "Best for",
                        value: status.preset.recommendation
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Text(status.statusText)
                    .font(MeetlessDesignTokens.Typography.caption.weight(.medium))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                    .frame(width: 118, alignment: .trailing)

                if case .downloading(let progress) = status.availability {
                    ProgressView(value: progress)
                        .frame(width: 110)
                }

                transcriptionModelAction(status)
            }
        }
        .padding(12)
        .background(MeetlessDesignTokens.Colors.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
    }

    private func transcriptionModelDetailLine(systemImage: String, label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
                .frame(width: 14, alignment: .center)

            Text(label)
                .font(MeetlessDesignTokens.Typography.caption.weight(.medium))
                .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(MeetlessDesignTokens.Typography.caption)
                .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func transcriptionModelAction(_ status: TranscriptionModelStatus) -> some View {
        switch status.availability {
        case .downloading:
            Button {
                viewModel.cancelTranscriptionModelDownload(status.id)
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        case .missing, .failed:
            Button {
                viewModel.downloadTranscriptionModel(status.id)
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .disabled(!status.canDownload)
        case .installed:
            Button(role: .destructive) {
                viewModel.removeTranscriptionModel(status.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(!status.canRemove)
        case .bundled:
            EmptyView()
        }
    }

    private var translationCard: some View {
        VStack(alignment: .leading, spacing: MeetlessDesignTokens.Layout.defaultGap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Transcript Output")
                    .font(MeetlessDesignTokens.Typography.windowTitle)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text("Translated transcript rows are shown live and saved in the session bundle.")
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }

            Picker("Output language", selection: $viewModel.transcriptOutputLanguage) {
                ForEach(TranscriptOutputLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)

            Picker("Translation provider", selection: $viewModel.transcriptTranslationProvider) {
                ForEach(TranscriptTranslationProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)

            if viewModel.selectedProviderUsesLLMPromptContext {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translation context")
                        .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                    Picker("Translation context", selection: $viewModel.transcriptTranslationDomain) {
                        ForEach(TranscriptTranslationDomain.allCases) { domain in
                            Text(domain.displayName).tag(domain)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 320, alignment: .leading)
                }

                if viewModel.isCustomTranslationPromptSelected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom prompt")
                            .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                        TextEditor(text: $viewModel.customTranslationPromptTemplate)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 136, maxHeight: 190)
                            .padding(6)
                            .background(MeetlessDesignTokens.Colors.appBackground)
                            .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                                    .stroke(MeetlessDesignTokens.Colors.separator)
                            )

                        if let validationMessage = viewModel.customTranslationPromptValidationMessage {
                            Text(validationMessage)
                                .font(MeetlessDesignTokens.Typography.caption)
                                .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                                .foregroundStyle(MeetlessDesignTokens.Colors.recordingRed)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Required placeholders: {{source_language}}, {{target_language}}, {{transcript}}. Ask the model to return only the translated text, avoid summaries, labels, and repeated source text.")
                            .font(MeetlessDesignTokens.Typography.caption)
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt preview")
                        .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                    ScrollView {
                        Text(viewModel.translationPromptPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 118, maxHeight: 158)
                    .background(MeetlessDesignTokens.Colors.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                            .stroke(MeetlessDesignTokens.Colors.separator)
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model")
                            .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
                        if !viewModel.translationModelPresets.isEmpty {
                            Picker(
                                "Model preset",
                                selection: Binding(
                                    get: { viewModel.selectedTranslationModelPresetID },
                                    set: { viewModel.selectTranslationModelPreset($0) }
                                )
                            ) {
                                ForEach(viewModel.translationModelPresets) { preset in
                                    Text(preset.displayName).tag(preset.id)
                                }
                                Text("Custom").tag(GeminiSettingsViewModel.customTranslationModelPresetID)
                            }
                            .pickerStyle(.menu)

                            if let selectedPreset = viewModel.translationModelPresets.first(where: { $0.id == viewModel.selectedTranslationModelPresetID }) {
                                Text(selectedPreset.detail)
                                    .font(MeetlessDesignTokens.Typography.caption)
                                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        TextField(viewModel.transcriptTranslationProvider.defaultModel, text: $viewModel.translationModel)
                            .textFieldStyle(.roundedBorder)
                            .font(MeetlessDesignTokens.Typography.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                            .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                            .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
                        TextField(
                            viewModel.transcriptTranslationProvider.defaultBaseURL.absoluteString,
                            text: $viewModel.translationBaseURL
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(MeetlessDesignTokens.Typography.body)
                    }
                }
            }
        }
        .padding(18)
        .background(MeetlessDesignTokens.Colors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                .stroke(MeetlessDesignTokens.Colors.separator)
        )
    }

    private var openAICard: some View {
        VStack(alignment: .leading, spacing: MeetlessDesignTokens.Layout.defaultGap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("OpenAI")
                    .font(MeetlessDesignTokens.Typography.windowTitle)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text("Save the API key used when OpenAI is selected for transcript translation.")
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }

            GeminiKeyStatusRow(
                status: viewModel.openAIKeyStatus,
                providerName: "OpenAI",
                missingMessage: "Add an OpenAI API key before translating with OpenAI."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("API key")
                    .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                SecureField(
                    viewModel.isOpenAIConfigured ? "Enter a new key to update" : "Enter OpenAI API key",
                    text: $viewModel.openAIAPIKeyInput
                )
                .textFieldStyle(.roundedBorder)
                .font(MeetlessDesignTokens.Typography.body)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.saveOpenAIAPIKey()
                } label: {
                    Label(viewModel.isOpenAIConfigured ? "Update Key" : "Save Key", systemImage: "key.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSaveOpenAIAPIKey)

                Button(role: .destructive) {
                    isConfirmingOpenAIDelete = true
                } label: {
                    Label("Delete Key", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isOpenAIConfigured)

                Spacer()
            }
        }
        .padding(18)
        .background(MeetlessDesignTokens.Colors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                .stroke(MeetlessDesignTokens.Colors.separator)
        )
    }

    private var googleTranslateCard: some View {
        VStack(alignment: .leading, spacing: MeetlessDesignTokens.Layout.defaultGap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Google Translate")
                    .font(MeetlessDesignTokens.Typography.windowTitle)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text("Save the API key used when Google Translate is selected for transcript translation.")
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }

            GeminiKeyStatusRow(
                status: viewModel.googleTranslateKeyStatus,
                providerName: "Google Translate",
                missingMessage: "Add a Google Translate API key before translating with Google Translate."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("API key")
                    .font(MeetlessDesignTokens.Typography.caption.weight(.semibold))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)

                SecureField(
                    viewModel.isGoogleTranslateConfigured ? "Enter a new key to update" : "Enter Google Translate API key",
                    text: $viewModel.googleTranslateAPIKeyInput
                )
                .textFieldStyle(.roundedBorder)
                .font(MeetlessDesignTokens.Typography.body)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.saveGoogleTranslateAPIKey()
                } label: {
                    Label(viewModel.isGoogleTranslateConfigured ? "Update Key" : "Save Key", systemImage: "key.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSaveGoogleTranslateAPIKey)

                Button(role: .destructive) {
                    isConfirmingGoogleTranslateDelete = true
                } label: {
                    Label("Delete Key", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.isGoogleTranslateConfigured)

                Spacer()
            }
        }
        .padding(18)
        .background(MeetlessDesignTokens.Colors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous)
                .stroke(MeetlessDesignTokens.Colors.separator)
        )
    }
}

private struct GeminiKeyStatusRow: View {
    let status: GeminiSettingsViewModel.KeyStatus
    let providerName: String
    let missingMessage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusDot(color: statusColor, size: .medium)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(MeetlessDesignTokens.Typography.body.weight(.semibold))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)
                Text(statusDetail)
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
            }
        }
        .padding(12)
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: MeetlessDesignTokens.Radius.panel, style: .continuous))
    }

    private var statusColor: Color {
        switch status {
        case .configured:
            return MeetlessDesignTokens.Colors.successGreen
        case .error:
            return MeetlessDesignTokens.Colors.warningAmber
        case .unknown, .notConfigured:
            return MeetlessDesignTokens.Colors.tertiaryText
        }
    }

    private var statusDetail: String {
        switch status {
        case .unknown:
            return "Checking the saved \(providerName) key."
        case .configured:
            return "A \(providerName) API key is saved in Keychain."
        case .notConfigured:
            return missingMessage
        case .error(let message):
            return message
        }
    }
}

#Preview {
    MeetlessRootView()
        .frame(width: 1080, height: 720)
}
