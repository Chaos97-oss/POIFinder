//
//  POIFinderApp.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import SwiftUI

@main
struct POIFinderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
