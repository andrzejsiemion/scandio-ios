import SwiftUI

struct CategorySection: View {
    @Bindable var model: AddCardModel

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        if model.showCategoryPicker {
            Section {
                LazyVGrid(columns: Self.columns, spacing: 10) {
                    ForEach(StoreCategory.allCases) { category in
                        Button {
                            model.selectedCategory = category
                        } label: {
                            Text(category.icon)
                                .font(.system(size: 26))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(model.selectedCategory == category ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                                .overlay {
                                    if model.selectedCategory == category {
                                        Circle().stroke(Color.accentColor, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                HStack {
                    Text("Category")
                    if model.isLoadingAISuggestion {
                        ProgressView().controlSize(.mini)
                    }
                    Spacer()
                    if model.selectedCategory != nil {
                        Button("Clear") { model.selectedCategory = nil }
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            } footer: {
                if AICategoryAdvisor.isAvailable {
                    Text("Suggested by Apple Intelligence — tap any icon to override.")
                } else {
                    Text("Pick a category to use as the card icon.")
                }
            }
        }
    }
}
