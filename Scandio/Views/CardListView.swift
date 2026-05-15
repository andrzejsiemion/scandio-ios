import SwiftUI
import SwiftData

struct CardListView: View {
    @Query private var cards: [LoyaltyCard]
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultsKey.cardSortOrder) private var sortOrderRaw: String = CardSortOrder.alphabetical.rawValue

    @State private var showingAddCard = false
    @State private var cardToEdit: LoyaltyCard?
    @State private var selectedCard: LoyaltyCard?
    @State private var searchText = ""
    @State private var cardToDelete: LoyaltyCard?
    @State private var showDeleteConfirmation = false
    @State private var showingSettings = false
    @State private var importAlert: String?
    @State private var showImportAlert = false
    @State private var currentQuickAccessID: LoyaltyCard.ID?
    @State private var pendingImport: [LoyaltyCard]?
    @State private var pendingDuplicateCount = 0
    @State private var showDuplicateDialog = false
    @AppStorage(DefaultsKey.duplicatePolicy) private var duplicatePolicyRaw: String = DuplicatePolicy.ask.rawValue

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var sortOrder: CardSortOrder {
        CardSortOrder(rawValue: sortOrderRaw) ?? .alphabetical
    }

    private var sortedCards: [LoyaltyCard] {
        switch sortOrder {
        case .alphabetical:
            return cards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .dateAdded:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .lastUsed:
            return cards.sorted {
                ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
            }
        }
    }

    private var filteredCards: [LoyaltyCard] {
        let source = sortedCards
        if searchText.isEmpty { return source }
        let query = searchText.lowercased()
        return source.filter { $0.name.lowercased().contains(query) }
    }

    /// Cards to show in the quick access carousel: favorites only.
    private var quickAccessCards: [LoyaltyCard] {
        cards
            .filter { $0.isFavorite }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "No Cards Yet",
                        systemImage: "creditcard",
                        description: Text("Tap + to add your first loyalty card.")
                    )
                } else if filteredCards.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Quick access carousel: last used + favorites
                            if searchText.isEmpty, !quickAccessCards.isEmpty {
                                quickAccessSection
                            }

                            // Card grid
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredCards) { card in
                                    cardGridItem(card)
                                }
                            }
                        }
                        .padding(12)
                        .animation(.default, value: filteredCards.count)
                    }
                }
            }
            .navigationTitle("Cards")
            .searchable(text: $searchText, prompt: "Search cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddCard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
            }
            .sheet(item: $cardToEdit) { card in
                AddCardView(existingCard: card)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(item: $selectedCard) { card in
                BarcodeFullScreenView(card: card) {
                    selectedCard = nil
                }
            }
            .alert("Delete Card", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let card = cardToDelete {
                        withAnimation {
                            modelContext.delete(card)
                        }
                        cardToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    cardToDelete = nil
                }
            } message: {
                if let card = cardToDelete {
                    Text("Are you sure you want to delete \"\(card.name)\"?")
                }
            }
            .task {
                precacheBarcodeThumbnails()
            }
            .onOpenURL { url in
                importCardsFromURL(url)
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

    // MARK: - Card Grid Item

    @ViewBuilder
    private func cardGridItem(_ card: LoyaltyCard) -> some View {
        CardRowView(card: card)
            .contentShape(Rectangle())
            .onTapGesture {
                openCard(card)
            }
            .overlay(alignment: .topTrailing) {
                if card.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .contextMenu {
                Button {
                    withAnimation {
                        card.isFavorite.toggle()
                    }
                } label: {
                    Label(
                        card.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: card.isFavorite ? "star.slash" : "star"
                    )
                }
                Button {
                    cardToEdit = card
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    cardToDelete = card
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // MARK: - Quick Access Carousel

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quick Access")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if quickAccessCards.count > 1 {
                    Text("Swipe for more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            TabView(selection: $currentQuickAccessID) {
                ForEach(quickAccessCards) { card in
                    quickAccessCard(card)
                        .padding(.horizontal, 1)
                        .tag(card.id as LoyaltyCard.ID?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 140)
            .onAppear {
                if currentQuickAccessID == nil {
                    currentQuickAccessID = quickAccessCards.first?.id
                }
            }

            // Page dots below the card
            if quickAccessCards.count > 1 {
                HStack(spacing: 6) {
                    ForEach(quickAccessCards) { card in
                        Circle()
                            .fill(card.id == currentQuickAccessID ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }


    @ViewBuilder
    private func quickAccessCard(_ card: LoyaltyCard) -> some View {
        let barcodeHeight: CGFloat = 80

        Button {
            openCard(card)
        } label: {
            VStack(spacing: 6) {
                if let image = BarcodeGenerator.shared.generate(
                    from: card.cardNumber,
                    type: card.barcodeType,
                    target: .quickAccess
                ) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: barcodeHeight)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                HStack(spacing: 4) {
                    if card.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(card.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openCard(_ card: LoyaltyCard) {
        Self.openCardHaptic.impactOccurred()
        card.lastUsedAt = .now
        selectedCard = card
    }

    /// Held + prepared so tap-to-open feels instantaneous instead of paying
    /// the haptic engine spin-up on every tap.
    private static let openCardHaptic: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        return g
    }()

    private func precacheBarcodeThumbnails() {
        // Capture value-type snapshots so the detached task doesn't touch the
        // SwiftData models off the main actor.
        let snapshots = cards.map {
            (number: $0.cardNumber, type: $0.barcodeType, isFavorite: $0.isFavorite)
        }
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for card in snapshots {
                    // Full-screen size is the most expensive consumer — precache it
                    // for every card so opening the detail view is a cache hit.
                    group.addTask {
                        _ = BarcodeGenerator.shared.generate(
                            from: card.number,
                            type: card.type,
                            target: .fullScreen
                        )
                    }
                    // Favorites also show in the quick-access carousel.
                    if card.isFavorite {
                        group.addTask {
                            _ = BarcodeGenerator.shared.generate(
                                from: card.number,
                                type: card.type,
                                target: .quickAccess
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Backup

    private var duplicatePolicy: DuplicatePolicy {
        DuplicatePolicy(rawValue: duplicatePolicyRaw) ?? .ask
    }

    private func importCardsFromURL(_ url: URL) {
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
