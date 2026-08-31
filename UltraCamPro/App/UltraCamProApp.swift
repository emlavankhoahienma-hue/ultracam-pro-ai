import SwiftUI

@main
struct UltraCamProApp: App {
    var body: some Scene {
        WindowGroup {
            CameraMainView()
                .preferredColorScheme(.dark)
                .statusBar(hidden: true)
        }
    }
}
