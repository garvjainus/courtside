import SwiftUI

struct SideMenu: View {
    var width: CGFloat = 250
    var isOpen: Bool
    @EnvironmentObject var authManager: AuthenticationManager  // Access auth manager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            NavigationLink(destination: HomeView()) {
                Text("Home")
            }
            NavigationLink(destination: StatsView()) {
                Text("Stats")
            }
            NavigationLink(destination: AnalyticsView()) {
                Text("Analytics")
            }
            NavigationLink(destination: FriendsView()) {
                Text("Friends")
            }
            NavigationLink(destination: StartGameView()) {
                Text("Start Game")
            }
            Spacer()

            // MARK: - Sign Out Button
            Button(action: {
                authManager.signOut { success in
                    if success {
                        print("✅ Signed out successfully")
                    } else {
                        print("❌ Sign out failed")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.red)
                    Text("Sign Out")
                        .foregroundColor(.red)
                        .bold()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white)
            .cornerRadius(10)
            .padding(.horizontal, 20)

        }
        .padding(.top, 50)
        .padding(.horizontal, 20)
        .frame(width: width, alignment: .leading)
        .background(Color(UIColor.systemGray6))
        .offset(x: isOpen ? 0 : -width)
        .animation(.easeInOut, value: isOpen)
//        .edgesIgnoringSafeArea(.vertical)
    }
}

struct SideMenu_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SideMenu(isOpen: true)
                .environmentObject(AuthenticationManager()) // Provide EnvironmentObject for preview
        }
    }
}
