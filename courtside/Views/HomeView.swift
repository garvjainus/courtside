import SwiftUI

struct HomeView: View {
    @State private var showMenu = false // Track menu state

    var body: some View {
        NavigationView {
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
                        showMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.horizontal.3")
                        .foregroundColor(.white)
                })

                // Side Menu (Slide In/Out)
                SideMenuView(showMenu: $showMenu)
            }
        }
    }
}

// 🔹 Side Menu View

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.dark)
    }
}
