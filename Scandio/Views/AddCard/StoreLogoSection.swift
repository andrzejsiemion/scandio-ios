import SwiftUI
import PhotosUI

struct StoreLogoSection: View {
    @Bindable var model: AddCardModel

    var body: some View {
        Section("Store Logo") {
            HStack {
                logoPreview

                VStack(alignment: .leading, spacing: 6) {
                    PhotosPicker(selection: $model.logoItem, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }

                    if model.logoData != nil || model.logoImage != nil {
                        Button(role: .destructive) {
                            model.removeLogo()
                        } label: {
                            Label("Remove Logo", systemImage: "xmark.circle")
                                .font(.callout)
                        }
                    }
                }
            }
            .onChange(of: model.logoItem) {
                Task { await model.loadLogoFromPickerItem() }
            }
        }
    }

    @ViewBuilder
    private var logoPreview: some View {
        if let logoImage = model.logoImage {
            Image(uiImage: logoImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let category = model.selectedCategory {
            Text(category.icon)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
        } else if let info = StoreLogo.lookup(model.name) {
            Text(info.icon)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
