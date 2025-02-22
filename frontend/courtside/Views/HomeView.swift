import SwiftUI

struct HomeView: View {
    @State private var showMenu = false // Track menu state
    @State private var selectedTab: String? = nil // Track current view

    var body: some View {
        NavigationView {
            ZStack {
                // Main Content
                VStack {
                    if selectedTab == nil {
                        Text("🏀 Welcome to Courtside AI!")
                            .foregroundColor(.white)
                            .font(.largeTitle)
                            .padding()
                    } else {
                        switch selectedTab {
                        case "Settings":
                            SettingsView()
                        case "Stats":
                            StatsView()
                        case "Analytics":
                            AnalyticsView()
                        case "GameHistory":
                            GameHistoryView(showMenu: $showMenu)
                        case "StartGame":
                            StartGameView()
                        case "Friends":
                            FriendsView()
                        default:
                            EmptyView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                
                .navigationBarTitle("", displayMode: .inline)
                .navigationBarItems(leading:
                    showMenu ? nil : Button(action: {
                        withAnimation {
                            showMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .foregroundColor(.white)
                    }
                )

                // Side Menu (Slide In/Out)
                CustomSideMenuView(showMenu: $showMenu, selectedTab: $selectedTab)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if UIImage(systemName: icon) != nil {
                    Image(systemName: icon)
                } else {
                    Text(icon) // Use emoji if icon is not an SF Symbol
                }
                Text(title)
                    .bold()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
    }
}


struct CustomSideMenuView: View {
    @Binding var showMenu: Bool
    @Binding var selectedTab: String?
    @EnvironmentObject var authManager: AuthenticationManager  // Use AuthenticationManager

    var body: some View {
        ZStack {
            if showMenu {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            showMenu = false
                        }
                    }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Menu")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .padding(.leading, 20)

                    Divider().background(Color.white)

                    // Menu Items
                    Group {
                        MenuButton(title: "Home", icon: "🏡") {
                            selectedTab = nil
                            showMenu = false
                        }
                        
                        MenuButton(title: "Settings", icon: "⚙️") {
                            selectedTab = "Settings"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Stats", icon: "🥇") {
                            selectedTab = "Stats"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Analytics", icon: "📊") {
                            selectedTab = "Analytics"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Game History", icon: "⏰") {
                            selectedTab = "GameHistory"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Start Game", icon: "🚀") {
                            selectedTab = "StartGame"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Friends", icon: "👭") {
                            selectedTab = "Friends"
                            showMenu = false
                        }
                    }
                    .foregroundColor(.white)

                    Spacer()

                    // 🔥 Sign Out Button
                    Button(action: {
                        authManager.signOut { success in
                            if success {
                                print("✅ Signed out successfully")
                                selectedTab = nil
                                showMenu = false
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
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.bottom,30)

                }
                .frame(width: 250)
                .background(Color.gray.opacity(0.9))
                .edgesIgnoringSafeArea(.all)
                .offset(x: showMenu ? 0 : -250) // Slide effect
                .animation(.easeInOut(duration: 0.3), value: showMenu)

                Spacer()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.dark)
    }
}
