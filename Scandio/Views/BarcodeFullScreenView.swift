import SwiftUI

struct BarcodeFullScreenView: View {
    let card: LoyaltyCard
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Card name
                Text(card.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.black)

                // Barcode — wrapped in HStack with Spacers to guarantee
                // horizontal centering regardless of intrinsic-size negotiation
                // between .resizable / .scaledToFit / VStack.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if let image = BarcodeGenerator.shared.generate(
                        from: card.cardNumber,
                        type: card.barcodeType,
                        size: barcodeSize
                    ) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: barcodeSize.width, height: barcodeSize.height)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                            Text("Could not generate barcode")
                        }
                        .foregroundStyle(.red)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                // Card number for manual entry
                Text(formattedCardNumber)
                    .font(.title3.monospaced())
                    .foregroundStyle(.black)
                    .textSelection(.enabled)
                    .kerning(2)

                // Barcode type
                Text(card.barcodeType.displayName)
                    .font(.caption)
                    .foregroundStyle(.gray)

                Spacer()
            }
            .padding(.horizontal, 24)

            // Close button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 60))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.gray)
            }
            .padding(20)
        }
        .statusBarHidden()
        .preferredColorScheme(.light)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            BrightnessManager.shared.activate()
        }
        .onDisappear {
            BrightnessManager.shared.deactivate()
        }
    }

    private var barcodeSize: CGSize {
        switch card.barcodeType {
        case .qrCode, .aztec:
            return CGSize(width: 280, height: 280)
        default:
            return CGSize(width: 340, height: 180)
        }
    }

    /// Format the card number with spaces every 4 digits for readability.
    private var formattedCardNumber: String {
        let number = card.cardNumber
        guard number.allSatisfy(\.isNumber), number.count > 4 else {
            return number
        }
        return stride(from: 0, to: number.count, by: 4).map { i in
            let start = number.index(number.startIndex, offsetBy: i)
            let end = number.index(start, offsetBy: min(4, number.count - i))
            return String(number[start..<end])
        }.joined(separator: " ")
    }
}
