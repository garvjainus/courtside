//
//  SideMenuView.swift
//  courtside
//
//  Created by Garv Jain on 2/22/25.
//

import SwiftUI

struct SideMenuView: View {
    @Binding var showMenu: Bool

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
                        .padding(.leading, 70)

                    Divider().background(Color.white)

                    // Navigation Links
                    Group {
                        NavigationLink(destination: HomeView()) {
                            Label("Home", systemImage: "house.fill")
                                .padding()
                        }
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gear")
                                .padding()
                        }
                        NavigationLink(destination: StatsView()) {
                            Label("Stats", systemImage: "star.fill")
                                .padding()
                        }
                        NavigationLink(destination: AnalyticsView()) {
                            Label("Analytics", systemImage: "chart.bar.fill")
                                .padding()
                        }
                        NavigationLink(destination: GameHistoryView(showMenu: $showMenu)) {  // ✅ Pass Binding
                            Label("Game History", systemImage: "clock.arrow.circlepath")
                                .padding()
                        }

                        NavigationLink(destination: StartGameView()) {
                            Label("Start Game", systemImage: "flag.checkered")
                                .padding()
                        }
                        NavigationLink(destination: FriendsView()) {
                            Label("Friends", systemImage: "person.2.fill")
                                .padding()
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

                Spacer() // Push content to the right
            }
        }
    }
}

// 🔹 Preview

struct SideMenuView_Previews: PreviewProvider {
    static var previews: some View {
        SideMenuView(showMenu: .constant(false))  // ✅ Provide a constant Binding for preview
    }
}

