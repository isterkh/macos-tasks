import SwiftUI

@main
struct DailyBoardApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 640, minHeight: 600)
        }
        .defaultSize(width: 1100, height: 700)
        .windowStyle(.automatic)
    }
}
