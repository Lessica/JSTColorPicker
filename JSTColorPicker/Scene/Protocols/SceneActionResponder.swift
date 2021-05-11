//
//  SceneActionResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol SceneActionResponder: CustomResponder {
    // Document Actions
    func openAction(_ sender: Any?)
    
    // Scene Tool Actions
    func useAnnotateItemAction(_ sender: Any?)
    func useMagnifyItemAction(_ sender: Any?)
    func useMinifyItemAction(_ sender: Any?)
    func useSelectItemAction(_ sender: Any?)
    func useMoveItemAction(_ sender: Any?)
    
    // Scene Preview Actions
    func fitWindowAction(_ sender: Any?)
    func fillWindowAction(_ sender: Any?)
    
    // Zooming Actions
    func zoomInAction(_ sender: Any?, centeringType center: SceneScrollView.ZoomingCenteringType)
    func zoomOutAction(_ sender: Any?, centeringType center: SceneScrollView.ZoomingCenteringType)
    func zoomToAction(_ sender: Any?, value: CGFloat)
    
    // Navigation Actions
    func navigateToAction(
        _ sender: Any?,
        direction: SceneScrollView.NavigationDirection,
        distance: SceneScrollView.NavigationDistance,
        centeringType center: SceneScrollView.NavigationCenteringType
    )
}

extension SceneScrollView {
    enum ZoomingCenteringType {
        case imageCenter
        case mouseLocation
    }
    
    enum NavigationCenteringType {
        case fromMouseLocation
        case global
    }

    enum NavigationDirection {
        case up
        case left
        case down
        case right
        
        static func direction(fromMenuItemIdentifier identifier: NSUserInterfaceItemIdentifier) -> NavigationDirection {
            switch identifier {
            case .moveUpBy1, .moveUpBy10, .moveUpBy100:
                return .up
            case .moveLeftBy1, .moveLeftBy10, .moveLeftBy100:
                return .left
            case .moveDownBy1, .moveDownBy10, .moveDownBy100:
                return .down
            case .moveRightBy1, .moveRightBy10, .moveRightBy100:
                return .right
            default:
                fatalError("invalid item identifier")
            }
        }
        
        static func direction(fromSpecialKey specialKey: NSEvent.SpecialKey) -> NavigationDirection {
            switch specialKey {
            case .upArrow:
                return .up
            case .leftArrow:
                return .left
            case .downArrow:
                return .down
            case .rightArrow:
                return .right
            default:
                fatalError("invalid special key")
            }
        }
    }
    
    enum NavigationDistance {
        case by1
        case by10
        case by100
        
        static func distance(from identifier: NSUserInterfaceItemIdentifier) -> NavigationDistance {
            switch identifier {
            case .moveUpBy1, .moveLeftBy1, .moveDownBy1, .moveRightBy1:
                return .by1
            case .moveUpBy10, .moveLeftBy10, .moveDownBy10, .moveRightBy10:
                return .by10
            case .moveUpBy100, .moveLeftBy100, .moveDownBy100, .moveRightBy100:
                return .by100
            default:
                fatalError("invalid item identifier")
            }
        }
        
        var actualDistance: CGFloat {
            switch self {
            case .by1:
                return 1
            case .by10:
                return 10
            case .by100:
                return 100
            }
        }
    }
}


// MARK: - Scene Navigation Menu Item Identifier
extension NSUserInterfaceItemIdentifier {
    private static let navigationPrefix     = "com.jst.JSTColorPicker.Navigation."
    
    static let moveUpBy1          = Self(Self.navigationPrefix + "moveUpBy1"        )
    static let moveUpBy10         = Self(Self.navigationPrefix + "moveUpBy10"       )
    static let moveUpBy100        = Self(Self.navigationPrefix + "moveUpBy100"      )
    static let moveLeftBy1        = Self(Self.navigationPrefix + "moveLeftBy1"      )
    static let moveLeftBy10       = Self(Self.navigationPrefix + "moveLeftBy10"     )
    static let moveLeftBy100      = Self(Self.navigationPrefix + "moveLeftBy100"    )
    static let moveDownBy1        = Self(Self.navigationPrefix + "moveDownBy1"      )
    static let moveDownBy10       = Self(Self.navigationPrefix + "moveDownBy10"     )
    static let moveDownBy100      = Self(Self.navigationPrefix + "moveDownBy100"    )
    static let moveRightBy1       = Self(Self.navigationPrefix + "moveRightBy1"     )
    static let moveRightBy10      = Self(Self.navigationPrefix + "moveRightBy10"    )
    static let moveRightBy100     = Self(Self.navigationPrefix + "moveRightBy100"   )
}


// MARK: - Scene Zooming Menu Item Identifier
extension NSUserInterfaceItemIdentifier {
    private static let zoomingPrefix     = "com.jst.JSTColorPicker.ZoomingLevel."
    
    static let zoomingLevel25     = Self(Self.zoomingPrefix + "25"     )
    static let zoomingLevel50     = Self(Self.zoomingPrefix + "50"     )
    static let zoomingLevel75     = Self(Self.zoomingPrefix + "75"     )
    static let zoomingLevel100    = Self(Self.zoomingPrefix + "100"    )
    static let zoomingLevel125    = Self(Self.zoomingPrefix + "125"    )
    static let zoomingLevel150    = Self(Self.zoomingPrefix + "150"    )
    static let zoomingLevel200    = Self(Self.zoomingPrefix + "200"    )
    static let zoomingLevel300    = Self(Self.zoomingPrefix + "300"    )
    static let zoomingLevel400    = Self(Self.zoomingPrefix + "400"    )
    static let zoomingLevel800    = Self(Self.zoomingPrefix + "800"    )
    static let zoomingLevel1600   = Self(Self.zoomingPrefix + "1600"   )
    static let zoomingLevel3200   = Self(Self.zoomingPrefix + "3200"   )
    static let zoomingLevel6400   = Self(Self.zoomingPrefix + "6400"   )
    static let zoomingLevel12800  = Self(Self.zoomingPrefix + "12800"  )
    static let zoomingLevel25600  = Self(Self.zoomingPrefix + "25600"  )
}


// MARK: - Scene Tool Menu Item Identifier
extension NSUserInterfaceItemIdentifier {
    private static let prefix     = "com.jst.JSTColorPicker.MenuItem."
    
    static let magicCursor        = Self(Self.prefix + "magicCursor"      )
    static let selectionArrow     = Self(Self.prefix + "selectionArrow"   )
    static let magnifyingGlass    = Self(Self.prefix + "magnifyingGlass"  )
    static let minifyingGlass     = Self(Self.prefix + "minifyingGlass"   )
    static let movingHand         = Self(Self.prefix + "movingHand"       )
}


// MARK: - Toolbar Item Identifier
extension NSToolbarItem.Identifier {
    private static let prefix     = "com.jst.JSTColorPicker.ToolbarItem."
    
    static let openItem           = Self(Self.prefix + "openItem")
    
    static let sceneToolGroup     = Self(Self.prefix + "sceneToolGroup")
    static let annotateItem       = Self(Self.prefix + "annotateItem")
    static let magnifyItem        = Self(Self.prefix + "magnifyItem")
    static let minifyItem         = Self(Self.prefix + "minifyItem")
    static let selectItem         = Self(Self.prefix + "selectItem")
    static let moveItem           = Self(Self.prefix + "moveItem")
    
    static let sceneActionGroup   = Self(Self.prefix + "sceneActionGroup")
    static let fitWindowItem      = Self(Self.prefix + "fitWindowItem")
    static let fillWindowItem     = Self(Self.prefix + "fillWindowItem")
    static let screenshotItem     = Self(Self.prefix + "screenshotItem")
    
    static let sidebarItem        = Self(Self.prefix + "sidebarItem")
    
    static let sidebarTrackingSeparator = Self(Self.prefix + "sidebarTrackingSeparator")
}
