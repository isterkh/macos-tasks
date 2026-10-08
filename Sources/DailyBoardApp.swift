import SwiftUI

@main
struct DailyBoardApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
    }
}
