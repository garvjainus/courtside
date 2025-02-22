import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject var gameManager: GameManager
    @Binding var showMenu: Bool

    var body: some View {
        VStack {
            Text("Game History")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            // Add your game history content here
            Text("No games played yet")
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
