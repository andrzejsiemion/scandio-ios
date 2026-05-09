import SwiftUI

struct CardBasicsSection: View {
    @Bindable var model: AddCardModel
    var onScan: () -> Void

    var body: some View {
        Section {
            TextField("Card Name", text: $model.name)
                .textContentType(.organizationName)
                .autocorrectionDisabled()
                .onChange(of: model.name) { model.nameChanged() }

            Picker("Barcode Type", selection: $model.barcodeType) {
                ForEach(BarcodeType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            TextField("Card Number", text: $model.cardNumber)
                .keyboardType(model.barcodeType.isNumericOnly ? .numberPad : .asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: model.barcodeType) { model.barcodeTypeChanged() }
                .onChange(of: model.cardNumber) { model.cardNumberChanged() }

            if let hint = model.inputHint {
                let hasError = !model.cardNumber.isEmpty && !model.hasValidNumber
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(hasError ? .red : .secondary)
            }
        }

        Section {
            Button(action: onScan) {
                Label("Scan Barcode with Camera", systemImage: "barcode.viewfinder")
            }
        }
    }
}
