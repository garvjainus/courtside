//
//  StatsView.swift
//  courtside
//
//  Created by emi zhang on 2/22/25.
//

import SwiftUI

struct StatsView: View {
    var body: some View {
        VStack {
            Text("Stats")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            // Add your stats content here
            Text("No stats available")
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}
