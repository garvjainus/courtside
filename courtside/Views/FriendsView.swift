//
//  FriendsView.swift
//  courtside
//
//  Created by emi zhang on 2/22/25.
//

import SwiftUI

struct FriendsView: View {
    var body: some View {
        VStack {
            Text("Friends")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            // Add your friends content here
            Text("No friends added yet")
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView()
    }
}
