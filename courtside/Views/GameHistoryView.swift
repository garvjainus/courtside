import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject var gameManager: GameManager
    @Binding var showMenu: Bool  // ✅ Add Binding

    var body: some View {
        ZStack {
            // Main Content
            VStack {
                Text("🏀 Welcome to Courtside AI!")
                    .foregroundColor(.white)
                    .font(.largeTitle)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                withAnimation {
                    showMenu.toggle()  // ✅ Use the binding correctly
                }
            }) {
                Image(systemName: "line.horizontal.3")
                    .foregroundColor(.white)
            })
        }
    }
}
