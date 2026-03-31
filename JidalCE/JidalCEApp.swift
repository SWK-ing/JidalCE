//
//  JidalCEApp.swift
//  JidalCE
//
//  Created by SHINWOONG LEE on 4/1/26.
//

import SwiftUI

@main
struct JidalCEApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
