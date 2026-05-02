import SwiftUI

struct ResultsListView: View {
    let results: [ScanResult]
    @Binding var selectedFileIds: Set<UUID>
    @State private var expandedCategoryIds: Set<UUID> = []
    @State private var didInitExpansion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scan Results")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("Potential cleanup: \(formatBytes(totalBytes))")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(results) { result in
                        DisclosureGroup(isExpanded: categoryExpansionBinding(result.id)) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(result.subcategories) { sub in
                                    HStack(alignment: .top, spacing: 8) {
                                        Toggle("", isOn: subcategoryBinding(sub))
                                            .toggleStyle(.checkbox)
                                            .labelsHidden()

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sub.name)
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.white)
                                            Text(formatBytes(sub.totalBytes))
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(0.7))
                                            Text(sub.files.map { $0.url.path }.joined(separator: "\n"))
                                                .font(.system(size: 9))
                                                .foregroundColor(.white.opacity(0.55))
                                        }
                                    }
                                }
                            }
                            .padding(.leading, 18)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Toggle("", isOn: categoryBinding(result))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.item.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(formatBytes(result.bytes))
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.7))
                                    Text(result.item.url.path)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !didInitExpansion {
                expandedCategoryIds = []
                didInitExpansion = true
            }
        }
    }

    private var totalBytes: Int64 {
        results.reduce(0) { $0 + $1.bytes }
    }

    private func categoryBinding(_ result: ScanResult) -> Binding<Bool> {
        let fileIds = result.allFileIds
        return Binding(
            get: { fileIds.allSatisfy { selectedFileIds.contains($0) } },
            set: { isSelected in
                if isSelected {
                    selectedFileIds.formUnion(fileIds)
                } else {
                    selectedFileIds.subtract(fileIds)
                }
            }
        )
    }

    private func subcategoryBinding(_ sub: ScanSubcategory) -> Binding<Bool> {
        let fileIds = sub.files.map { $0.id }
        return Binding(
            get: { fileIds.allSatisfy { selectedFileIds.contains($0) } },
            set: { isSelected in
                if isSelected {
                    selectedFileIds.formUnion(fileIds)
                } else {
                    selectedFileIds.subtract(fileIds)
                }
            }
        )
    }

    private func categoryExpansionBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedCategoryIds.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategoryIds.insert(id)
                } else {
                    expandedCategoryIds.remove(id)
                }
            }
        )
    }
}
