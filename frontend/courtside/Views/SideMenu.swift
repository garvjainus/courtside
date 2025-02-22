import SwiftUI

struct SideMenu: View {
    var width: CGFloat = 250
    var isOpen: Bool

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
            NavigationLink(destination: AccountView()) {
                Text("Account")
            }
            Spacer()
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
        NavigationView { // Embed in NavigationView for preview purposes.
            SideMenu(isOpen: true)
        }
    }
}
