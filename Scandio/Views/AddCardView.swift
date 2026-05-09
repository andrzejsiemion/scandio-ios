import SwiftUI
import SwiftData

struct AddCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var model: AddCardModel
    @State private var showingScanner = false

    init(existingCard: LoyaltyCard? = nil) {
        _model = State(wrappedValue: AddCardModel(existingCard: existingCard))
    }

    var body: some View {
        NavigationStack {
            Form {
                CardBasicsSection(model: model) { showingScanner = true }
                TileColorSection(model: model)
                CategorySection(model: model)
                StoreLogoSection(model: model)

                if let validationError = model.validationError {
                    Section {
                        Text(validationError)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                BarcodePreviewSection(model: model)
            }
            .navigationTitle(model.isEditing ? "Edit Card" : "New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if model.save(into: modelContext) { dismiss() }
                    }
                    .disabled(!model.canSave)
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                BarcodeScannerView { value, type in
                    model.cardNumber = value
                    model.barcodeType = type
                    model.validationError = nil
                    showingScanner = false
                } onDismiss: {
                    showingScanner = false
                }
                .ignoresSafeArea()
            }
        }
    }
}
