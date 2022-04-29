//  Created by Rob Mayoff on 4/28/17.

import Cocoa

enum DragEndpointState {
    
    /// not captured
    case idle
    
    /// captured
    case captured
    
    /// act like source
    case source
    
    /// act like target
    case target
    
    /// act like target, but forbidden due to some reasons
    case forbidden
}

protocol DragEndpoint: NSView {
    var dragEndpointState: DragEndpointState { get set }
}

