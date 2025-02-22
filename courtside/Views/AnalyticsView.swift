//
//  AnalyticsView.swift
//  courtside
//
//  Created by emi zhang on 2/22/25.
//

import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        VStack {
            Text("Analytics")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            // Add your analytics content here
            Text("No analytics data available")
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
    }
}
