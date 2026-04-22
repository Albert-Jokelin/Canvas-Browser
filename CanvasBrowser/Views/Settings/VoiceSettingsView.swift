import SwiftUI

struct VoiceSettingsView: View {
    @AppStorage("voiceControlEnabled") private var voiceControlEnabled = true
    @AppStorage("voiceActivationMode") private var voiceActivationMode = "toggleOnOff"
    @AppStorage("showTranscriptionOverlay") private var showTranscriptionOverlay = true

    @StateObject private var voiceService = VoiceControlService()
    @State private var showCommandReference = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Voice Control", isOn: $voiceControlEnabled)
                Text("Control Canvas Browser with voice commands. Use Option+V or the mic button to activate.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Authorization") {
                HStack {
                    Image(systemName: voiceService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(voiceService.isAuthorized ? .canvasGreen : .canvasRed)

                    Text(voiceService.isAuthorized ? "Microphone & Speech authorized" : "Authorization required")
                        .font(.subheadline)

                    Spacer()

                    if !voiceService.isAuthorized {
                        Button("Authorize") {
                            voiceService.requestAuthorization()
                        }
                    }
                }

                if let error = voiceService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.canvasRed)
                }
            }

            Section("Activation") {
                Picker("Mode", selection: $voiceActivationMode) {
                    Text("Toggle On/Off").tag("toggleOnOff")
                    Text("Push to Talk").tag("pushToTalk")
                }
                Text("Toggle On/Off keeps listening until you say \"stop listening\" or press Option+V again. Push to Talk listens only while holding the mic button.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Display") {
                Toggle("Show Transcription Overlay", isOn: $showTranscriptionOverlay)
                Text("Shows live transcription and command feedback at the bottom of the browser.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                DisclosureGroup("Voice Commands Reference", isExpanded: $showCommandReference) {
                    VoiceCommandReferenceContent()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            voiceService.requestAuthorization()
        }
    }
}

// MARK: - Voice Command Reference

private struct VoiceCommandReferenceContent: View {
    let categories: [(String, [(String, String)])] = [
        ("Navigation", [
            ("go back / back", "Navigate back"),
            ("go forward / forward", "Navigate forward"),
            ("reload / refresh", "Reload page"),
            ("stop", "Stop loading"),
            ("go home / home", "Go to home page"),
        ]),
        ("Tabs", [
            ("new tab", "Open new tab"),
            ("close tab", "Close current tab"),
            ("next tab", "Switch to next tab"),
            ("previous tab", "Switch to previous tab"),
            ("tab 3 / switch to tab 3", "Switch to tab by number"),
        ]),
        ("URL & Search", [
            ("go to apple.com", "Navigate to URL"),
            ("search for weather", "Search Google"),
            ("google swift tutorials", "Search Google"),
        ]),
        ("Page", [
            ("scroll up / scroll down", "Scroll page"),
            ("top / bottom", "Scroll to top/bottom"),
            ("zoom in / zoom out", "Zoom page"),
            ("find cookies", "Find text on page"),
        ]),
        ("UI Controls", [
            ("open chat / chat", "Toggle AI chat panel"),
            ("show bookmarks", "Toggle bookmarks"),
            ("show history", "Toggle history"),
            ("fullscreen", "Toggle fullscreen"),
            ("settings", "Open settings"),
        ]),
        ("AI & GenTab", [
            ("ask AI what is this page about", "Send query to AI"),
            ("create gen tab", "Create new GenTab"),
        ]),
        ("Browser", [
            ("bookmark this", "Add bookmark"),
            ("screenshot", "Take screenshot"),
            ("print page", "Print current page"),
            ("reader mode", "Toggle reader mode"),
        ]),
        ("Voice", [
            ("stop listening / cancel", "Stop voice control"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CanvasSpacing.lg) {
            ForEach(categories, id: \.0) { category in
                VStack(alignment: .leading, spacing: CanvasSpacing.xs) {
                    Text(category.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.canvasSecondaryLabel)
                        .textCase(.uppercase)

                    ForEach(category.1, id: \.0) { command in
                        HStack {
                            Text("\"\(command.0)\"")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.canvasLabel)
                            Spacer()
                            Text(command.1)
                                .font(.system(size: 12))
                                .foregroundColor(.canvasSecondaryLabel)
                        }
                    }
                }
                if category.0 != categories.last?.0 {
                    Divider()
                }
            }
        }
        .padding(.vertical, CanvasSpacing.sm)
    }
}
