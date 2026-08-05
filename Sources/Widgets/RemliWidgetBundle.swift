import SwiftUI
import WidgetKit

@main
struct RemliWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaptureWidget()
        CaptureControl()
    }
}
