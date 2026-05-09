import SwiftUI

struct BarcodePreviewSection: View {
    @Bindable var model: AddCardModel

    var body: some View {
        if !model.cardNumber.isEmpty {
            Section("Preview") {
                if let image = barcodeImage {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .background(Color.white)
                        Spacer()
                    }
                } else {
                    Text("Enter a valid number to see preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var barcodeImage: UIImage? {
        guard case .success(let number) = model.validatedNumber() else { return nil }
        return BarcodeGenerator.shared.generate(
            from: number,
            type: model.barcodeType,
            size: CGSize(width: 300, height: 120)
        )
    }
}
