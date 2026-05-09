import SwiftUI

struct TileColorSection: View {
    @Bindable var model: AddCardModel

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        Section("Tile Color") {
            LazyVGrid(columns: Self.columns, spacing: 10) {
                ForEach(AddCardModel.presetColors, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex).gradient)
                        .frame(width: 36, height: 36)
                        .overlay {
                            if model.isColorSelected(hex) {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            }
                        }
                        .onTapGesture { model.selectColor(hex) }
                }

                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        if model.showCustomColor {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                    }
                    .onTapGesture { model.showCustomColor = true }
            }
            .padding(.vertical, 4)

            if model.showCustomColor {
                ColorPicker("Pick Color", selection: $model.selectedColor, supportsOpacity: false)

                HStack {
                    Text("#")
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                    TextField("Hex (e.g. FF5733)", text: $model.customHexText)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: model.customHexText) { model.customHexChanged() }
                }
            }
        }
    }
}
