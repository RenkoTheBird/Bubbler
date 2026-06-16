//
//  BubblerAppApp.swift
//  BubblerApp
//
//  Created by Nishan Narain on 5/22/26.
//

import SwiftUI

@main
struct BubblerAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
