import SwiftUI

@main
struct LotteryBangBangDaApp: App {
    var body: some Scene {
        WindowGroup {
            // 这里原本是 ContentView()，一定要改成我们的 RootView
            RootView()
                .preferredColorScheme(.dark) // 强制深色模式，符合彩票机的质感
        }
    }
}
