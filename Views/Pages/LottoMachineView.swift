import SwiftUI
import SpriteKit

struct LottoMachineView: View {
    @ObservedObject var viewModel: HomeViewModel
    
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size), options: [.allowsTransparency])
                .background(Color.clear)
        }
    }
    
    func makeScene(size: CGSize) -> SKScene {
        let scene = LottoScene(size: size, type: viewModel.currentLottery)
        scene.scaleMode = .aspectFit
        scene.backgroundColor = .clear
        scene.onBallSelected = { num, color in
            viewModel.addBall(number: num, color: color)
        }
        return scene
    }
}
