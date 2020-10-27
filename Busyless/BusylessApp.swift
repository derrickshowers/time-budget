//
//  Busyless.swift
//  Busyless
//
//  Created by Derrick Showers on 8/8/20.
//  Copyright © 2020 Derrick Showers. All rights reserved.
//

import SwiftUI
import BusylessDataLayer

@main
struct BusylessApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}