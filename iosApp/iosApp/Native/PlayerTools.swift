import AVFAudio
import SwiftUI
import ComposeApp

/// The player tools of the selected player, from `NativePlayerTools`.
@MainActor
final class PlayerToolsModel: ObservableObject {
    static let shared = PlayerToolsModel()

    @Published private(set) var tools: NativeTools
    @Published private(set) var dsp: NativeDsp
    /// The tool screen that Now Playing shows.
    @Published var sheet: PlayerToolSheet?
    private var tasks: [Task<Void, Never>] = []

    private init() {
        tools = NativePlayerTools.shared.state.value
        dsp = NativePlayerTools.shared.dspState.value
        tasks = [
            Task { [weak self] in for await value in NativePlayerTools.shared.state { self?.tools = value } },
            Task { [weak self] in for await value in NativePlayerTools.shared.dspState { self?.dsp = value } },
        ]
    }
}

/// A tool screen opened from Now Playing.
enum PlayerToolSheet: String, Identifiable {
    case streamDetails, dsp, announcement, ambientSound
    var id: String { rawValue }
}

/// The tools section of the Now Playing options menu.
struct PlayerToolsMenuSection: View {
    @ObservedObject private var model = PlayerToolsModel.shared

    var body: some View {
        let tools = model.tools
        Section {
            if tools.stream != nil {
                Button("Stream Details", systemImage: "waveform.badge.magnifyingglass") { model.sheet = .streamDetails }
            }
            if tools.canConfigureDsp {
                Button("Equalizer (DSP)", systemImage: "slider.vertical.3") { model.sheet = .dsp }
            }
            if tools.canAnnounceText || tools.canAnnounceVoice {
                Button(L("announcement_send", "Announce"), systemImage: "megaphone") { model.sheet = .announcement }
            }
            if tools.overlay != nil {
                Button(L("ambient_sound_title", "Ambient Sound"), systemImage: "cloud.rain") { model.sheet = .ambientSound }
            }
            if let hosts = tools.djHosts {
                Menu {
                    Picker("DJ", selection: Binding(
                        get: { tools.djHostId ?? "" },
                        set: { NativePlayerTools.shared.selectDj(hostId: $0.isEmpty ? nil : $0) }
                    )) {
                        Text(L("ambient_sound_off", "Off")).tag("")
                        ForEach(hosts, id: \.id) { host in Text(host.name).tag(host.id) }
                    }
                } label: {
                    Label("AI Radio DJ", systemImage: "music.mic")
                }
            }
        }
    }
}

struct PlayerToolSheetView: View {
    let sheet: PlayerToolSheet

    var body: some View {
        switch sheet {
        case .streamDetails: StreamDetailsSheet()
        case .dsp: DspSheet()
        case .announcement: AnnouncementSheet()
        case .ambientSound: AmbientSoundSheet()
        }
    }
}

/// A sheet with a title and a Done button.
private struct ToolSheet<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L("common_done", "Done")) { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Where the audio comes from and the players it goes to, with the format at each stage.
private struct StreamDetailsSheet: View {
    @ObservedObject private var model = PlayerToolsModel.shared
    @State private var route: PresentedRoute?

    var body: some View {
        ToolSheet(title: "Stream Details") {
            if let stream = model.tools.stream {
                List {
                    Section("Source") {
                        stage(stream.input)
                        if let origin = stream.origin {
                            Button { route = PresentedRoute(.item(origin)) } label: {
                                LabeledContent("Playing From", value: origin.title)
                            }
                        }
                    }
                    if !stream.outputs.isEmpty {
                        Section(L("quality_dialog_output", "Output")) {
                            ForEach(Array(stream.outputs.enumerated()), id: \.offset) { _, output in stage(output) }
                        }
                    }
                }
                .sheet(item: $route) { PresentedRouteSheet(route: $0.route) }
            } else {
                ContentUnavailableView(L("players_nothing", "Nothing Playing"), systemImage: "waveform")
            }
        }
    }

    private func stage(_ stage: NativeStreamStage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stage.name ?? "Unknown")
                .font(.body.weight(.semibold))
            if let format = stage.format {
                Text(format)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Turns the player's DSP on or off and applies a preset.
private struct DspSheet: View {
    @ObservedObject private var model = PlayerToolsModel.shared

    var body: some View {
        ToolSheet(title: "Equalizer") {
            let dsp = model.dsp
            switch dsp.load {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error:
                ContentUnavailableView("Couldn't Load the DSP Settings", systemImage: "exclamationmark.triangle")
            default:
                List {
                    Toggle("DSP", isOn: Binding(get: { dsp.enabled }, set: { _ in NativePlayerTools.shared.toggleDsp() }))
                    if !dsp.presets.isEmpty {
                        Section(L("dsp_presets", "Presets")) {
                            ForEach(Array(dsp.presets.enumerated()), id: \.offset) { index, name in
                                Button {
                                    NativePlayerTools.shared.applyDspPreset(index: Int32(index))
                                } label: {
                                    HStack {
                                        Text(name).foregroundStyle(Color.primary)
                                        Spacer()
                                        if name == dsp.appliedPreset {
                                            Image(systemName: "checkmark").foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { NativePlayerTools.shared.loadDsp() }
    }
}

/// A typed or spoken announcement on the selected player.
private struct AnnouncementSheet: View {
    @ObservedObject private var model = PlayerToolsModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var speaks = false
    @State private var message = ""
    @State private var chime = true
    @State private var customVolume = false
    @State private var volume: Double = 50
    @State private var recording: LiveRecording?

    var body: some View {
        ToolSheet(title: "Announce") {
            Form {
                if model.tools.canAnnounceText && model.tools.canAnnounceVoice {
                    Picker("Mode", selection: $speaks) {
                        Text(L("announcement_tab_type", "Type")).tag(false)
                        Text(L("announcement_tab_speak", "Speak")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if !showsSpeak {
                    Section {
                        TextField(L("announcement_message", "Message"), text: $message, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
                Section {
                    Toggle("Chime First", isOn: $chime)
                    Toggle(L("announcement_custom_volume", "Custom Volume"), isOn: $customVolume)
                    if customVolume {
                        HStack {
                            Slider(value: $volume, in: 0...100)
                            Text("\(Int(volume))").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    if showsSpeak {
                        holdToTalk
                    } else {
                        Button("Send") {
                            NativePlayerTools.shared.announce(
                                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                                chime: chime,
                                volume: customVolume ? KotlinInt(int: Int32(volume)) : nil
                            )
                            dismiss()
                        }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .task {
            if let setting = try? await NativePlayerTools.shared.announcementChime() { chime = setting.boolValue }
        }
    }

    private var showsSpeak: Bool { model.tools.canAnnounceVoice && (speaks || !model.tools.canAnnounceText) }

    private var holdToTalk: some View {
        Label(recording == nil ? "Hold to Talk" : "Release to Send", systemImage: recording == nil ? "mic" : "mic.fill")
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(recording == nil ? Color.accentColor : Color.red)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startRecording() }
                    .onEnded { _ in
                        recording?.finish()
                        if recording != nil { dismiss() }
                        recording = nil
                    }
            )
            .sensoryFeedback(.start, trigger: recording != nil)
    }

    private func startRecording() {
        guard recording == nil else { return }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            AVAudioApplication.requestRecordPermission { _ in }
            return
        }
        recording = NativePlayerTools.shared.speak(chime: chime, volume: customVolume ? KotlinInt(int: Int32(volume)) : nil)
    }
}

/// A looping sound that the server mixes into the queue stream.
private struct AmbientSoundSheet: View {
    @ObservedObject private var model = PlayerToolsModel.shared
    @State private var sounds: [NativeSound]?
    @State private var volume: Double = 100

    var body: some View {
        ToolSheet(title: "Ambient Sound") {
            if let sounds {
                let overlay = model.tools.overlay
                List {
                    Section {
                        Button { NativePlayerTools.shared.setOverlay(uri: nil, volume: Int32(volume)) } label: {
                            row("Off", selected: overlay?.enabled != true)
                        }
                        ForEach(sounds, id: \.uri) { sound in
                            Button {
                                NativePlayerTools.shared.setOverlay(uri: sound.uri, volume: Int32(volume))
                            } label: {
                                row(sound.name, selected: overlay?.enabled == true && overlay?.sourceUri == sound.uri)
                            }
                        }
                    }
                    Section("Volume") {
                        Slider(value: $volume, in: 0...100) { editing in
                            guard !editing, overlay?.enabled == true, let uri = overlay?.sourceUri else { return }
                            NativePlayerTools.shared.setOverlay(uri: uri, volume: Int32(volume))
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            volume = Double(model.tools.overlay?.volume ?? 100)
            sounds = (try? await NativePlayerTools.shared.sounds()) ?? []
        }
    }

    private func row(_ title: String, selected: Bool) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.primary)
            Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
        }
    }
}
