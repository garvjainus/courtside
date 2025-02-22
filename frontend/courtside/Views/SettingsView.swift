import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            // Add your settings content here
            Text("No settings available")
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
} 
