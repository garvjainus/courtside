//
//  StartGameView.swift
//  courtside
//
//  Created by emi zhang on 2/22/25.
//

import SwiftUI

struct StartGameView: View {
    var body: some View {
        VStack {
            Text("Start Game")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            // Add your start game content here
            Button(action: {
                // Add game start logic here
            }) {
                Text("Start New Game")
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

struct StartGameView_Previews: PreviewProvider {
    static var previews: some View {
        StartGameView()
    }
}
