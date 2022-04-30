// Created by Rob Mayoff on 4/29/17.

import Cocoa

final class DragConnectionController: NSObject, NSDraggingSource {

    var pasteboardType: NSPasteboard.PasteboardType
    
    weak var sourceEndpoint: DragEndpoint?
    weak var targetEndpoint: DragEndpoint?
    
    init(type: NSPasteboard.PasteboardType) {
        pasteboardType = type
    }
    
    func testConnection(to target: DragEndpoint? = nil) {
        targetEndpoint = target
    }

    func doConnection(to target: DragEndpoint) {
        targetEndpoint = target
        if let sourceEndpoint = sourceEndpoint,
           let targetEndpoint = targetEndpoint
        {
            debugPrint("connect \(sourceEndpoint) to \(targetEndpoint)")
        }
    }

    func trackDrag(forMouseDownEvent mouseDownEvent: NSEvent, in sourceEndpoint: DragEndpoint, with object: Any) {
        self.sourceEndpoint = sourceEndpoint
        let item = NSDraggingItem(
            pasteboardWriter: NSPasteboardItem(
                pasteboardPropertyList: object,
                ofType: pasteboardType
            )!
        )
        item.setDraggingFrame(sourceEndpoint.frame, contents: nil /* no placeholder image */)
        let session = sourceEndpoint.beginDraggingSession(with: [item], event: mouseDownEvent, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // handle modifier keys manually
        switch context {
            case .withinApplication:
            return [.move, .copy]
            case .outsideApplication:
                return []
            @unknown default:
                fatalError()
        }
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        sourceEndpoint?.dragEndpointState = .source
        lineOverlay = DragLineOverlay(startScreenPoint: screenPoint, endScreenPoint: screenPoint)
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        lineOverlay?.endScreenPoint = screenPoint
        if let targetEndpoint = targetEndpoint,
           targetEndpoint.dragEndpointState.isForbidden
        {
            lineOverlay?.isEnabled = false
        } else {
            lineOverlay?.isEnabled = true
        }
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        lineOverlay?.removeFromScreen()
        sourceEndpoint?.dragEndpointState = .idle
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        // handle modifier keys manually
        return true
    }

    private var lineOverlay: DragLineOverlay?
    
    deinit {
        debugPrint("\(className):\(#function)")
    }

}

