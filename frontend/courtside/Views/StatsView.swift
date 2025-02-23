//
//  StatsView.swift
//  courtside
//
//  Created by emi zhang on 2/22/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct StatsView: View {
    @State private var games: [Game] = []
    @State private var overallStats: OverallStats?
    
    var body: some View {
        VStack {
            Text("Stats")
                .foregroundColor(.white)
                .font(.largeTitle)
                .padding()
            
            if games.isEmpty {
                Text("No stats available")
                    .foregroundColor(.white)
                    .padding()
            } else {
                List(games) { game in
                    VStack(alignment: .leading) {
                        Text("Game vs \(game.opponentTeamScore) - \(game.teamScore)")
                            .font(.headline)
                        Text("Points: \(game.personalPoints), Rebounds: \(game.personalRebounds), Assists: \(game.personalAssists)")
                        Text("Steals: \(game.personalSteals), Blocks: \(game.personalBlocks), Turnovers: \(game.personalTurnovers)")
                    }
                    .padding()
                }
                .background(Color.black)
            }
            
            if let stats = overallStats {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Overall Stats")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Total Games: \(stats.totalGames)")
                    Text("Total Points: \(stats.totalPoints)")
                    Text("Total Rebounds: \(stats.totalRebounds)")
                    Text("Total Assists: \(stats.totalAssists)")
                    Text("Total Steals: \(stats.totalSteals)")
                    Text("Total Blocks: \(stats.totalBlocks)")
                    Text("Total Turnovers: \(stats.totalTurnovers)")
                    Text("Field Goal Percentage: \(String(format: "%.2f", stats.fieldGoalPercentage))%")
                }
                .foregroundColor(.white)
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            fetchGameStats()
        }
    }
    
    func fetchGameStats() {
        let db = Firestore.firestore()
        db.collection("games").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("Error fetching games: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.games = documents.compactMap { try? $0.data(as: Game.self) }
            self.calculateOverallStats()
        }
    }
    
    func calculateOverallStats() {
        guard !games.isEmpty else { return }
        let totalGames = games.count
        let totalPoints = games.reduce(0) { $0 + $1.personalPoints }
        let totalRebounds = games.reduce(0) { $0 + $1.personalRebounds }
        let totalAssists = games.reduce(0) { $0 + $1.personalAssists }
        let totalSteals = games.reduce(0) { $0 + $1.personalSteals }
        let totalBlocks = games.reduce(0) { $0 + $1.personalBlocks }
        let totalTurnovers = games.reduce(0) { $0 + $1.personalTurnovers }
        let totalFGMade = games.reduce(0) { $0 + $1.personalFGMade }
        let totalFGAttempted = games.reduce(0) { $0 + $1.personalFGAttempted }
        let fieldGoalPercentage = totalFGAttempted > 0 ? (Double(totalFGMade) / Double(totalFGAttempted)) * 100 : 0.0
        
        overallStats = OverallStats(
            totalGames: totalGames,
            totalPoints: totalPoints,
            totalRebounds: totalRebounds,
            totalAssists: totalAssists,
            totalSteals: totalSteals,
            totalBlocks: totalBlocks,
            totalTurnovers: totalTurnovers,
            fieldGoalPercentage: fieldGoalPercentage
        )
    }
}

struct OverallStats {
    let totalGames: Int
    let totalPoints: Int
    let totalRebounds: Int
    let totalAssists: Int
    let totalSteals: Int
    let totalBlocks: Int
    let totalTurnovers: Int
    let fieldGoalPercentage: Double
}

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}

