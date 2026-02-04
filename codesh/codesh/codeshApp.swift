//
//  codeshApp.swift
//  codesh
//
//  Created by Eli Zibin on 2026-02-04.
//

import SwiftUI

@main
struct codeshApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
