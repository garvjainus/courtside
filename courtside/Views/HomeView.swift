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
                .navigationBarItems(leading: Button(action: {
                    withAnimation {
                        showMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.horizontal.3")
                        .foregroundColor(.white)
                })

                // Side Menu (Slide In/Out)
                CustomSideMenuView(showMenu: $showMenu, selectedTab: $selectedTab)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Custom Side Menu View
struct CustomSideMenuView: View {
    @Binding var showMenu: Bool
    @Binding var selectedTab: String?

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
                        MenuButton(title: "Home", icon: "house.fill") {
                            selectedTab = nil
                            showMenu = false
                        }
                        
                        MenuButton(title: "Settings", icon: "gear") {
                            selectedTab = "Settings"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Stats", icon: "star.fill") {
                            selectedTab = "Stats"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Analytics", icon: "chart.bar.fill") {
                            selectedTab = "Analytics"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Game History", icon: "clock.arrow.circlepath") {
                            selectedTab = "GameHistory"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Start Game", icon: "flag.checkered") {
                            selectedTab = "StartGame"
                            showMenu = false
                        }
                        
                        MenuButton(title: "Friends", icon: "person.2.fill") {
                            selectedTab = "Friends"
                            showMenu = false
                        }
                    }
                    .foregroundColor(.white)

                    Spacer()
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

// Menu Button Component
struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.dark)
    }
}
