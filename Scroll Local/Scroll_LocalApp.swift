//
//  Scroll_LocalApp.swift
//  Scroll Local
//
//  Created by Eli Gooding on 2/3/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            #if DEBUG
            print("Firebase configured in AppDelegate")
            #endif
        }
        return true
    }
}

@main
struct Scroll_LocalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if firebaseService.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .onAppear {
                #if DEBUG
                print("App appeared, checking auth state")
                if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil {
                    PreviewFirebaseService.shared.debugPrintAuthState()
                } else {
                    firebaseService.debugPrintAuthState()
                }
                #endif
            }
        }
    }
}


