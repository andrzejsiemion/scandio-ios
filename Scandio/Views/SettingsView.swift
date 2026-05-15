import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [LoyaltyCard]

    @AppStorage(DefaultsKey.cardSortOrder) private var sortOrder: String = CardSortOrder.alphabetical.rawValue
    @AppStorage(DefaultsKey.brightnessEnabled) private var brightnessEnabled: Bool = true
    @AppStorage(DefaultsKey.brightnessLevel) private var brightnessLevel: Double = 1.0
    @AppStorage(DefaultsKey.appTheme) private var appTheme: String = AppTheme.system.rawValue
    @AppStorage(DefaultsKey.appLanguage) private var storedLanguage: String = AppLanguage.en.rawValue
    @AppStorage(DefaultsKey.duplicatePolicy) private var duplicatePolicyRaw: String = DuplicatePolicy.ask.rawValue

    @State private var pickerLanguage: String = AppLanguage.en.rawValue
    @State private var showRestartAlert = false

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupData: Data?
    @State private var importAlert: String?
    @State private var showImportAlert = false
    @State private var pendingImport: [LoyaltyCard]?
    @State private var pendingDuplicateCount = 0
    @State private var showDuplicateDialog = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sort Cards By") {
                    Picker("Sort Order", selection: $sortOrder) {
                        ForEach(CardSortOrder.allCases) { order in
                            Text(order.displayName).tag(order.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Toggle("Boost Brightness", isOn: $brightnessEnabled)

                    if brightnessEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "sun.min")
                                    .foregroundStyle(.secondary)
                                Slider(value: $brightnessLevel, in: 0.3...1.0, step: 0.05)
                                Image(systemName: "sun.max.fill")
                                    .foregroundStyle(.secondary)
                            }
                            Text("Brightness: \(Int(brightnessLevel * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Barcode Display")
                } footer: {
                    Text("When enabled, screen brightness increases when viewing a barcode. Lower values save battery.")
                }

                Section {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Light keeps Scandio in light mode regardless of system settings.")
                }

                Section {
                    Picker("Language", selection: $pickerLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .onChange(of: pickerLanguage) { _, newValue in
                        if newValue != storedLanguage {
                            showRestartAlert = true
                        }
                    }
                } header: {
                    Text("Language")
                }

                Section {
                    Picker("On Duplicate", selection: $duplicatePolicyRaw) {
                        ForEach(DuplicatePolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy.rawValue)
                        }
                    }

                    Button {
                        exportCards()
                    } label: {
                        Label("Export All Cards", systemImage: "square.and.arrow.up")
                    }
                    .disabled(cards.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import Cards", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("On Duplicate controls what happens when an imported card already exists locally.")
                }

                Section("About") {
                    NavigationLink("About Scandio") {
                        AboutView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                pickerLanguage = storedLanguage
            }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("Cancel", role: .cancel) {
                    pickerLanguage = storedLanguage
                }
                Button("Restart") {
                    storedLanguage = pickerLanguage
                    let lang = AppLanguage(rawValue: pickerLanguage) ?? .en
                    lang.apply()
                    exit(0)
                }
            } message: {
                Text("Restart Scandio now to apply the language change?")
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: BackupDocument(data: backupData ?? Data()),
                contentType: .scandioBackup,
                defaultFilename: "cards_backup_\(Self.formattedDate)"
            ) { _ in }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.scandioBackup]
            ) { result in
                importCardsFromFile(result)
            }
            .alert("Import Complete", isPresented: $showImportAlert) {
                Button("OK") {}
            } message: {
                Text(importAlert ?? "")
            }
            .confirmationDialog(
                "Duplicate Cards Found",
                isPresented: $showDuplicateDialog,
                titleVisibility: .visible
            ) {
                Button("Skip Duplicates") { resolvePendingImport(.skip) }
                Button("Merge with Existing") { resolvePendingImport(.merge) }
                Button("Add as New Cards") { resolvePendingImport(.duplicate) }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("\(pendingDuplicateCount) duplicate card(s) found. What would you like to do?")
            }
        }
    }

    private var duplicatePolicy: DuplicatePolicy {
        DuplicatePolicy(rawValue: duplicatePolicyRaw) ?? .ask
    }

    // MARK: - Backup helpers

    /// Locale-stable filename date (YYYY-MM-DD). Using ISO8601 avoids the
    /// locale-dependent surprises a custom-pattern `DateFormatter` would
    /// introduce in non-US locales.
    private static var formattedDate: String {
        Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    private func exportCards() {
        do {
            backupData = try BackupManager.exportCards(cards)
            showingExporter = true
        } catch {
            importAlert = String(localized: "Export failed: \(error.localizedDescription)")
            showImportAlert = true
        }
    }

    private func importCardsFromFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            switch BackupManager.parse(from: url) {
            case .failure(let error):
                importAlert = String(localized: "Import failed: \(error.localizedDescription)")
                showImportAlert = true
            case .success(let incoming):
                let dups = BackupManager.duplicateCount(of: incoming, in: cards)
                if dups > 0, duplicatePolicy == .ask {
                    pendingImport = incoming
                    pendingDuplicateCount = dups
                    showDuplicateDialog = true
                } else {
                    applyImport(incoming, policy: duplicatePolicy.resolved ?? .skip)
                }
            }
        } catch {
            importAlert = String(localized: "Import failed: \(error.localizedDescription)")
            showImportAlert = true
        }
    }

    private func resolvePendingImport(_ policy: ResolvedDuplicatePolicy) {
        guard let pending = pendingImport else { return }
        applyImport(pending, policy: policy)
        pendingImport = nil
    }

    private func applyImport(_ incoming: [LoyaltyCard], policy: ResolvedDuplicatePolicy) {
        let result = BackupManager.apply(
            incoming: incoming,
            into: modelContext,
            existing: cards,
            policy: policy
        )
        importAlert = result.localizedMessage
        showImportAlert = true
    }
}

private struct AboutView: View {
    @Environment(\.openURL) private var openURL

    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    private let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    Text("Scandio")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Author") {
                LabeledContent("Developer", value: "Andrzej Siemion")
                Button {
                    openURL(URL(string: "https://siemion.pro/scandio/")!)
                } label: {
                    HStack {
                        Text("Website")
                        Spacer()
                        Text("siemion.pro/scandio")
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                Button {
                    openURL(URL(string: "https://github.com/andrzejsiemion")!)
                } label: {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Text("@andrzejsiemion")
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }

            Section("Support") {
                Text("Scandio is free and open source. If you find it useful, consider starring the project on GitHub.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Legal") {
                Button {
                    openURL(URL(string: "https://siemion.pro/scandio/privacy/")!)
                } label: {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                LabeledContent("License", value: "MIT")
                Button {
                    openURL(URL(string: "https://github.com/andrzejsiemion/scandio-ios/blob/main/LICENSE")!)
                } label: {
                    HStack {
                        Text("View License")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                Button {
                    openURL(URL(string: "https://github.com/andrzejsiemion/scandio-ios")!)
                } label: {
                    HStack {
                        Text("Source Code")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
