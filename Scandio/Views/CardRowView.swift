import SwiftUI

struct CardRowView: View {
    let card: LoyaltyCard

    @State private var logoImage: UIImage?

    private var cardColor: Color {
        Color(hex: card.colorHex)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Logo: uploaded image > customIcon > store emoji > generic icon
            if let logoImage {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let icon = card.customIcon {
                Text(icon)
                    .font(.system(size: 44))
                    .frame(height: 56)
            } else if let info = StoreLogo.lookup(card.name) {
                Text(info.icon)
                    .font(.system(size: 44))
                    .frame(height: 56)
            } else {
                Image(systemName: "creditcard")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(height: 56)
            }

            // Card name
            Text(card.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardColor.gradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task(id: card.logoData) {
            // Decode JPEG off the main thread, once per data change.
            // Without this, UIImage(data:) ran inside `body` on every render.
            guard let data = card.logoData else {
                logoImage = nil
                return
            }
            let decoded = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
            logoImage = decoded
        }
    }
}
