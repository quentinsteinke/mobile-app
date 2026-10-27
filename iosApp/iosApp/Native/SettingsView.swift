import SwiftUI
import ComposeApp

@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var state: NativeSettingsState
    let screen = NativeSettings()
    private var task: Task<Void, Never>?

    init() {
        state = screen.state.value
        task = Task { [weak self, screen] in
            for await value in screen.state { self?.state = value }
        }
    }

    deinit {
        task?.cancel()
        screen.close()
    }
}

/// The native settings: the server connection, signing in, appearance, the local player and
/// the general options. [isTopLevel] is the screen before the tabs (not connected or not signed
/// in); signing in there goes on to the tabs.
struct SettingsView: View {
    var isTopLevel: Bool
    var bottomInset: CGFloat = 0
    /// Opens the Compose settings, for the options that have no native form yet.
    var openMoreSettings: () -> Void = {}

    @StateObject private var model = SettingsModel()
    @State private var host = ""
    @State private var port = "8095"
    @State private var isTls = false
    @State private var basePath = ""
    @State private var username = ""
    @State private var password = ""
    @State private var fieldsFilled = false
    @FocusState private var focusedField: Field?
    @State private var fold: FoldDivision?
    @State private var size: CGSize = .zero

    private enum Field { case host, port, basePath, remoteId, username, password }

    private var state: NativeSettingsState { model.state }

    var body: some View {
        NavigationStack {
            Group {
                // In book posture the connection is on one side of the fold, the options on the
                // other. A wide window keeps the form at a readable width.
                if let fold, fold.posture == .book, fold.splits(size) {
                    FoldSplit(fallback: .horizontal) {
                        Form { connectionSections }
                    } second: {
                        Form { optionSections }
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                } else {
                    Form {
                        connectionSections
                        optionSections
                    }
                    .readableWidth(720, in: size.width)
                }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .readsFold(into: $fold)
            .navigationTitle("Settings")
            .toolbar {
                if isTopLevel && state.phase == .signedIn {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { KmpHelper.shared.settingsGoHome() }
                    }
                }
            }
            .safeAreaPadding(.bottom, bottomInset)
        }
        .onAppear(perform: fillFields)
        .onChange(of: state.savedHost) { _, _ in fillFields() }
        .onChange(of: state.phase) { oldPhase, newPhase in
            // Signing in on the first screen goes on to the music.
            if isTopLevel && newPhase == .signedIn && oldPhase != .signedIn {
                KmpHelper.shared.settingsGoHome()
            }
        }
    }

    @ViewBuilder
    private var connectionSections: some View {
        if let title = state.localNetworkTitle, let body = state.localNetworkBody {
            localNetworkSection(title: title, body: body)
        }
        serverSection
        if state.phase == .awaitingAuth || state.phase == .signedIn {
            accountSection
        }
    }

    @ViewBuilder
    private var optionSections: some View {
        appearanceSection
        if state.phase == .signedIn {
            LocalPlayerSection(model: model)
        }
        generalSection
    }

    private func fillFields() {
        guard !fieldsFilled, !state.savedHost.isEmpty else { return }
        fieldsFilled = true
        host = state.savedHost
        port = state.savedPort
        isTls = state.savedTls
        basePath = state.savedBasePath
    }

    // MARK: - Server

    @ViewBuilder
    private var serverSection: some View {
        switch state.phase {
        case .disconnected:
            Section {
                Picker("Connection", selection: Binding(
                    get: { state.usesWebRtc },
                    set: { model.screen.setUsesWebRtc(enabled: $0) }
                )) {
                    Text("Local Network").tag(false)
                    Text("Remote Access").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                if state.usesWebRtc {
                    TextField("Remote ID", text: Binding(
                        get: { state.webrtcRemoteId },
                        set: { model.screen.setWebrtcRemoteId(remoteId: $0) }
                    ))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .remoteId)
                    .submitLabel(.go)
                    .onSubmit { model.screen.connectWebRtc() }
                } else {
                    LabeledContent("Address") {
                        TextField("homeassistant.local", text: $host)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .host)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .port }
                    }
                    LabeledContent("Port") {
                        TextField("8095", text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .port)
                    }
                    Toggle("Secure Connection (TLS)", isOn: $isTls)
                    LabeledContent("Base Path") {
                        TextField("Optional", text: $basePath)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .basePath)
                            .submitLabel(.go)
                            .onSubmit(connect)
                    }
                }
                Button(action: connect) {
                    HStack {
                        Text("Connect")
                        if state.connectInFlight {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(state.connectInFlight || (!state.usesWebRtc && port.isEmpty))
            } header: {
                Text("Server")
            } footer: {
                if let error = state.errorMessage {
                    Text(error).foregroundStyle(.red)
                } else if state.usesWebRtc {
                    Text("Connect from anywhere with the Remote ID that the Music Assistant server shows in its settings.")
                } else {
                    Text("The address and port of your Music Assistant server.")
                }
            }
            if !state.history.isEmpty {
                Section("Recent Servers") {
                    ForEach(state.history, id: \.historyKey) { entry in
                        Button {
                            use(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                Text(entry.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                model.screen.removeHistory(historyKey: entry.historyKey)
                            }
                        }
                    }
                }
            }
        case .connecting:
            Section("Server") {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(state.connectingTo.map { "Connecting to \($0)…" } ?? "Connecting…")
                        .foregroundStyle(.secondary)
                }
                Button("Cancel", role: .cancel) { model.screen.disconnect() }
            }
        case .awaitingAuth, .signedIn:
            Section("Server") {
                if let name = state.serverName {
                    LabeledContent("Name", value: name)
                }
                if let address = state.serverAddress {
                    LabeledContent("Address", value: address)
                }
                if let version = state.serverVersion {
                    LabeledContent("Version", value: version)
                }
                Button("Disconnect", role: .destructive) { model.screen.disconnect() }
            }
        default:
            EmptyView()
        }
    }

    private func connect() {
        focusedField = nil
        if state.usesWebRtc {
            model.screen.connectWebRtc()
        } else {
            model.screen.connect(host: host, port: port, isTls: isTls, basePath: basePath)
        }
    }

    private func use(_ entry: NativeHistoryEntry) {
        if entry.isWebRtc {
            model.screen.setUsesWebRtc(enabled: true)
            model.screen.setWebrtcRemoteId(remoteId: entry.remoteId ?? "")
        } else {
            model.screen.setUsesWebRtc(enabled: false)
            host = entry.host ?? ""
            port = entry.port.map { String($0.intValue) } ?? "8095"
            isTls = entry.isTls
            basePath = entry.basePath
        }
    }

    private func localNetworkSection(title: String, body: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: "network")
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            Button("Got It") { model.screen.dismissLocalNetworkHint() }
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        if state.phase == .signedIn {
            Section("Account") {
                if let user = state.userDescription {
                    LabeledContent("Signed In As", value: user)
                }
                Button("Sign Out", role: .destructive) { model.screen.signOut() }
            }
        } else {
            Section {
                if state.authProviders.isEmpty {
                    HStack {
                        Text("Loading sign-in options…").foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                    Button("Try Again") { model.screen.retryProviders() }
                }
                if let builtin = state.authProviders.first(where: { $0.isBuiltin }) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn(builtin) }
                    Button {
                        signIn(builtin)
                    } label: {
                        HStack {
                            Text("Sign In")
                            if state.authBusy {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty || state.authBusy)
                }
                if let homeAssistant = state.authProviders.first(where: { $0.isHomeAssistant }) {
                    Button {
                        model.screen.signInWithBrowser(providerId: homeAssistant.providerId)
                    } label: {
                        Label("Sign In with Home Assistant", systemImage: "house")
                    }
                    .disabled(state.authBusy)
                }
            } header: {
                Text("Sign In")
            } footer: {
                if let error = state.authError {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
    }

    private func signIn(_ provider: NativeAuthProvider) {
        guard !username.isEmpty, !password.isEmpty else { return }
        focusedField = nil
        model.screen.signIn(providerId: provider.providerId, username: username, password: password)
    }

    // MARK: - Appearance and general

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: Binding(
                get: { state.themeName },
                set: { model.screen.setTheme(name: $0) }
            )) {
                Text("System").tag("FollowSystem")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var generalSection: some View {
        Section {
            Toggle("Allow Landscape", isOn: Binding(
                get: { state.allowLandscape },
                set: { model.screen.setAllowLandscape(enabled: $0) }
            ))
            if state.phase == .signedIn {
                Button("More Settings…", action: openMoreSettings)
            }
            Button {
                model.screen.shareLogs(chooserTitle: "Share Logs")
            } label: {
                HStack {
                    Text("Share Logs")
                    if state.isPreparingShare {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(state.isPreparingShare)
            if state.hasCrashLog {
                Button("Share Crash Log") { model.screen.shareCrashLog(chooserTitle: "Share Crash Log") }
                    .disabled(state.isPreparingShare)
                Button("Delete Crash Log", role: .destructive) { model.screen.deleteCrashLog() }
            }
            Link("Documentation", destination: URL(string: "https://music-assistant.github.io/mobile-app/")!)
            LabeledContent("Version", value: state.appVersion)
        } header: {
            Text("General")
        } footer: {
            Text("Music Assistant is a free, open-source music server. More settings, such as the car and DSP options, are in More Settings.")
        }
    }
}

/// The local player: this device as a Music Assistant player, with its name, codec, 24-bit
/// audio and buffer. Changes apply with Save; Save asks first while the player plays.
private struct LocalPlayerSection: View {
    @ObservedObject var model: SettingsModel

    private var player: NativeLocalPlayer { model.state.localPlayer }

    var body: some View {
        Section {
            Toggle("Use This Device as a Player", isOn: Binding(
                get: { player.enabled },
                set: { model.screen.setLocalPlayerEnabled(enabled: $0) }
            ))
            if player.enabled {
                LabeledContent("Name") {
                    TextField("My Phone", text: Binding(
                        get: { player.name },
                        set: { model.screen.setLocalPlayerName(name: $0) }
                    ))
                    .multilineTextAlignment(.trailing)
                }
                Picker("Codec", selection: Binding(
                    get: { player.codecName },
                    set: { model.screen.setLocalPlayerCodec(name: $0) }
                )) {
                    ForEach(player.codecNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Toggle("24-bit Audio", isOn: Binding(
                    get: { player.hiRes },
                    set: { model.screen.setLocalPlayerHiRes(enabled: $0) }
                ))
                .disabled(!player.hiResAvailable)
                Stepper(value: Binding(
                    get: { Int(player.bufferSeconds) },
                    set: { model.screen.setLocalPlayerBuffer(seconds: Int32($0)) }
                ), in: 5...30, step: 5) {
                    LabeledContent("Buffer", value: "\(player.bufferSeconds) s")
                }
                HStack {
                    Button("Reset") { model.screen.resetLocalPlayer() }
                        .disabled(!player.isResettable)
                    Spacer()
                    Button("Save") { model.screen.saveLocalPlayer() }
                        .fontWeight(.semibold)
                        .disabled(!player.isSavable)
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Local Player")
        } footer: {
            Text("Plays Music Assistant on this device. FLAC is lossless; Opus uses less data.")
        }
        .alert("Interrupt Playback?", isPresented: Binding(
            get: { player.isConfirmationPending },
            set: { if !$0 { model.screen.dismissLocalPlayer() } }
        )) {
            Button("Apply", role: .destructive) { model.screen.confirmLocalPlayer() }
            Button("Cancel", role: .cancel) { model.screen.dismissLocalPlayer() }
        } message: {
            Text("The local player restarts with the new settings, which stops what it plays now.")
        }
    }
}
