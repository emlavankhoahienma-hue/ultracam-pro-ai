import SwiftUI

@main
struct UltraCamProApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
                .preferredColorScheme(.dark)
                .statusBar(hidden: true)
        }
    }
}
