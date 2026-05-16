import Foundation
import AppKit
import SwiftUI

enum PublicLogRedaction {
    static func sessionIdentifier(for directoryURL: URL) -> String {
        let identifier = directoryURL.lastPathComponent
        return identifier.isEmpty ? "unknown-session" : identifier
    }

    static func storageRootLabel(for directoryURL: URL) -> String {
        let productComponent = directoryURL.deletingLastPathComponent().lastPathComponent
        let containerComponent = directoryURL.lastPathComponent

        let productLabel = productComponent.isEmpty ? "ApplicationSupport" : productComponent
        let containerLabel = containerComponent.isEmpty ? "storage" : containerComponent
        return "\(productLabel).\(containerLabel)"
    }
}

private enum RuntimeStorageProbe {
    private static let environmentKey = "MEETLESS_PRINT_STORAGE_ROOT"

    static func logIfRequested(fileManager: FileManager = .default) {
        let value = ProcessInfo.processInfo.environment[environmentKey]?.lowercased()
        guard value == "1" || value == "true" else {
            return
        }

        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("MEETLESS_RUNTIME_STORAGE_ROOT=unavailable")
            return
        }

        let storageRoot = applicationSupportURL
            .appendingPathComponent("Meetless", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)

        print("MEETLESS_RUNTIME_STORAGE_ROOT=redacted; container=\(PublicLogRedaction.storageRootLabel(for: storageRoot))")
    }
}

@main
struct MeetlessApp: App {
    init() {
        RuntimeStorageProbe.logIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            MeetlessRootView()
                .frame(minWidth: 960, minHeight: 680)
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Meetless") {
                    AboutWindowPresenter.shared.show()
                }
            }
        }
    }
}

@MainActor
private final class AboutWindowPresenter {
    static let shared = AboutWindowPresenter()
    private var windowController: NSWindowController?

    private init() {}

    func show() {
        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = MeetlessAboutView(info: .current)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Meetless"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MeetlessAboutInfo {
    let appName: String
    let versionLine: String
    let copyright: String

    static var current: MeetlessAboutInfo {
        let bundle = Bundle.main
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Meetless"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let copyright = bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String

        return MeetlessAboutInfo(
            appName: appName,
            versionLine: Self.versionLine(version: version, build: build),
            copyright: copyright?.isEmpty == false ? copyright ?? "" : "Local-first meeting recorder"
        )
    }

    private static func versionLine(version: String?, build: String?) -> String {
        switch (version?.isEmpty == false ? version : nil, build?.isEmpty == false ? build : nil) {
        case let (.some(version), .some(build)):
            return "Version \(version) (\(build))"
        case let (.some(version), .none):
            return "Version \(version)"
        case let (.none, .some(build)):
            return "Build \(build)"
        case (.none, .none):
            return "Development build"
        }
    }
}

private struct MeetlessAboutView: View {
    let info: MeetlessAboutInfo

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                appIcon

                VStack(spacing: 8) {
                    Text(info.appName)
                        .font(.system(size: 32, weight: .semibold))
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.primaryText)

                    Text(info.versionLine)
                        .font(MeetlessDesignTokens.Typography.body)
                        .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                        .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                }

                Text("Record, transcribe, translate, and summarize meetings on your Mac.")
                    .font(.system(size: 14, weight: .regular))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 340)

                Text("A product by Tobiccino")
                    .font(MeetlessDesignTokens.Typography.body.weight(.semibold))
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.primaryBlue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                Divider()

                Text(info.copyright)
                    .font(MeetlessDesignTokens.Typography.caption)
                    .tracking(MeetlessDesignTokens.Typography.letterSpacing)
                    .foregroundStyle(MeetlessDesignTokens.Colors.tertiaryText)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
        .padding(.top, 42)
        .frame(width: 480, height: 420)
        .background(MeetlessDesignTokens.Colors.windowBackground)
    }

    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: 112, height: 112)
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 6)
    }
}
