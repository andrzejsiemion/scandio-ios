import SwiftUI

struct BarcodePreviewSection: View {
    @Bindable var model: AddCardModel

    @State private var image: UIImage?

    private var previewKey: String {
        "\(model.cardNumber)|\(model.barcodeType.rawValue)"
    }

    var body: some View {
        if !model.cardNumber.isEmpty {
            Section("Preview") {
                if let image {
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
            .task(id: previewKey) {
                await regenerate()
            }
        }
    }

    private func regenerate() async {
        guard case .success(let number) = model.validatedNumber() else {
            image = nil
            return
        }
        let type = model.barcodeType
        let generated = await Task.detached(priority: .userInitiated) {
            BarcodeGenerator.shared.generate(from: number, type: type, target: .preview)
        }.value
        image = generated
    }
}
