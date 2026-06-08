import SwiftUI

struct WhoIsPopupView: View {
    let characterName: String
    @State private var viewModel = AIViewModel()
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Кто такой \(characterName)?").font(.headline)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            ScrollView {
                Text(viewModel.streamedResponse)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
        .task {
            await viewModel.whoIs(name: characterName, context: "")
        }
    }
}
