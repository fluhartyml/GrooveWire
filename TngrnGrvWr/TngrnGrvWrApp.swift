//
//  TngrnGrvWrApp.swift
//  TngrnGrvWr
//
//  Created by Michael Fluharty on 3/13/26.
//

import SwiftUI
import SwiftData

@main
struct TngrnGrvWrApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Bridge.self,
            Track.self,
            Message.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
