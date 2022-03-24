// Created by Rob Mayoff on 4/29/17.

import Cocoa

final class DragConnectionController: NSObject, NSDraggingSource {

    var pasteboardType: NSPasteboard.PasteboardType
    var sourceEndpoint: DragEndpoint?
    
    init(type: NSPasteboard.PasteboardType) {
        pasteboardType = type
    }

    func connect(to target: DragEndpoint) {
        debugPrint("connect \(sourceEndpoint!) to \(target)")
    }

    func trackDrag(forMouseDownEvent mouseDownEvent: NSEvent, in sourceEndpoint: DragEndpoint, with object: Any) {
        self.sourceEndpoint = sourceEndpoint
        let item = NSDraggingItem(
            pasteboardWriter: NSPasteboardItem(
                pasteboardPropertyList: object,
                ofType: pasteboardType
            )!
        )
        item.setDraggingFrame(sourceEndpoint.frame, contents: nil)
        let session = sourceEndpoint.beginDraggingSession(with: [item], event: mouseDownEvent, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
            case .withinApplication:
                return [.copy, .link]
            case .outsideApplication:
                return []
            @unknown default:
                fatalError()
        }
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        sourceEndpoint?.state = .source
        lineOverlay = DragLineOverlay(startScreenPoint: screenPoint, endScreenPoint: screenPoint)
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        lineOverlay?.endScreenPoint = screenPoint
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        lineOverlay?.removeFromScreen()
        sourceEndpoint?.state = .idle
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { return true }

    private var lineOverlay: DragLineOverlay?

}

