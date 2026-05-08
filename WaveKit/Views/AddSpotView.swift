import SwiftUI

struct AddSpotView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var favoritesStore: FavoritesStore

    @State private var urlText = ""
    @State private var errorMessage: String?
    @State private var didAdd = false

    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Add Surf Spot")
                    .font(.headline)

                Text("Paste a Surfline surf report URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            // URL Input
            VStack(alignment: .leading, spacing: 6) {
                TextField("Surfline URL", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isURLFieldFocused)
                    .onSubmit {
                        addSpot()
                    }

                Text("Example: surfline.com/surf-report/venice-breakwater/590927...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(didAdd ? "Added!" : "Add Spot", action: addSpot)
                    .keyboardShortcut(.defaultAction)
                    .disabled(urlText.isEmpty || didAdd)
            }

            // Paste button
            if let clipboardContent = NSPasteboard.general.string(forType: .string),
               clipboardContent.contains("surfline.com") {
                Button {
                    urlText = clipboardContent
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(24)
        .frame(width: 350)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isURLFieldFocused = true
            }
        }
    }

    private func addSpot() {
        guard !urlText.isEmpty else { return }

        errorMessage = nil

        switch favoritesStore.addSpotFromURL(urlText) {
        case .success:
            didAdd = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                urlText = ""
                didAdd = false
                isURLFieldFocused = true
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AddSpotView(favoritesStore: FavoritesStore.shared)
}
