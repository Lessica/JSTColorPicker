//  Created by Rob Mayoff on 4/28/17.

import Cocoa

enum DragEndpointState {
    case idle
    case source
    case target
}

protocol DragEndpoint: NSView {
    var state: DragEndpointState { get set }
}

