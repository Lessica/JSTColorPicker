//  Created by Rob Mayoff on 4/28/17.

import Cocoa

enum DragEndpointState: Equatable {
    
    /// not captured
    case idle
    
    /// captured
    case captured
    
    /// act like source
    case source
    
    /// act like target
    case target
    
    /// act like target, but forbidden due to some reasons
    case forbidden(reason: String)
    
    var isForbidden: Bool {
        switch self {
        case .forbidden(_):
            return true
        default:
            break
        }
        return false
    }
}

protocol DragEndpoint: NSView {
    var dragEndpointState: DragEndpointState { get set }
}

