import SwiftUI
import Charts

extension Chart {
    func chartAnimate(_ animate: Bool) -> some View {
        self.animation(.easeInOut(duration: 1), value: animate)
    }
} 