//
//  defaults:swift
//  JSTColorPicker
//
//  Created by Darwin on 2/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension UserDefaults.Key {
    
    static let AppleMomentumScrollSupported         : UserDefaults.Key     = "AppleMomentumScrollSupported"                    // Bool
    
    static let lastSelectedDeviceUDID               : UserDefaults.Key     = "defaults:lastSelectedDeviceUDID"                 // String
    static let lastSelectedTemplateUUID             : UserDefaults.Key     = "defaults:lastSelectedTemplateUUID"               // String
    static let enableNetworkDiscovery               : UserDefaults.Key     = "defaults:enableNetworkDiscovery"                 // Bool
    
    static let toggleTableColumnIdentifier          : UserDefaults.Key     = "defaults:toggleTableColumnIdentifier"            // Bool
    static let toggleTableColumnSimilarity          : UserDefaults.Key     = "defaults:toggleTableColumnSimilarity"            // Bool
    static let toggleTableColumnTag                 : UserDefaults.Key     = "defaults:toggleTableColumnTag"                   // Bool
    static let toggleTableColumnDescription         : UserDefaults.Key     = "defaults:toggleTableColumnDescription"           // Bool
    
    static let togglePreviewArea                    : UserDefaults.Key     = "defaults:togglePreviewArea"                      // Bool
    static let togglePreviewColor                   : UserDefaults.Key     = "defaults:togglePreviewColor"                     // Bool

    static let toggleTemplateDetailedInformation    : UserDefaults.Key     = "defaults:toggleTemplateDetailedInformation"      // Bool
    static let togglePrimaryInspectorHSBFormat      : UserDefaults.Key     = "defaults:togglePrimaryInspectorHSBFormat"        // Bool
    static let toggleSecondaryInspectorHSBFormat    : UserDefaults.Key     = "defaults:toggleSecondaryInspectorHSBFormat"      // Bool
    static let usesAlternativeAreaRepresentation    : UserDefaults.Key     = "defaults:usesAlternativeAreaRepresentation"      // Bool
    
    static let drawSceneBackground                  : UserDefaults.Key     = "defaults:drawSceneBackground"                    // Bool
    static let drawTagsInScene                      : UserDefaults.Key     = "defaults:drawTagsInScene"                        // Bool
    static let drawBordersInScene                   : UserDefaults.Key     = "defaults:drawBordersInScene"                     // Bool
    static let drawGridsInScene                     : UserDefaults.Key     = "defaults:drawGridsInScene"                       // Bool
    static let drawRulersInScene                    : UserDefaults.Key     = "defaults:drawRulersInScene"                      // Bool
    static let drawBackgroundInGridView             : UserDefaults.Key     = "defaults:drawBackgroundInGridView"               // Bool
    static let drawAnnotatorsInGridView             : UserDefaults.Key     = "defaults:drawAnnotatorsInGridView"               // Bool
    static let hideBordersWhenResize                : UserDefaults.Key     = "defaults:hideBordersWhenResize"                  // Bool
    static let hideGridsWhenResize                  : UserDefaults.Key     = "defaults:hideGridsWhenResize"                    // Bool
    static let hideAnnotatorsWhenResize             : UserDefaults.Key     = "defaults:hideAnnotatorsWhenResize"               // Bool
    static let usesPredominantAxisScrolling         : UserDefaults.Key     = "defaults:usesPredominantAxisScrolling"           // Bool
    
    static let usesDetailedToolTips                 : UserDefaults.Key     = "defaults:usesDetailedToolTips"                   // Bool
    static let confirmBeforeDelete                  : UserDefaults.Key     = "defaults:confirmBeforeDelete"                    // Bool
    static let ignoreRepeatedInsertion              : UserDefaults.Key     = "defaults:ignoreRepeatedInsertion"                // Bool
    static let ignoreInvalidDeletion                : UserDefaults.Key     = "defaults:ignoreInvalidDeletion"                  // Bool
    static let zIndexBySize                         : UserDefaults.Key     = "defaults:zIndexBySize"                           // Bool
    static let maximumItemCountEnabled              : UserDefaults.Key     = "defaults:maximumItemCountEnabled"                // Bool
    static let maximumItemCount                     : UserDefaults.Key     = "defaults:maximumItemCount"                       // Int
    static let maximumTagPerItemEnabled             : UserDefaults.Key     = "defaults:maximumTagPerItemEnabled"               // Bool
    static let maximumTagPerItem                    : UserDefaults.Key     = "defaults:maximumTagPerItem"                      // Int
    static let replaceSingleTagWhileDrop            : UserDefaults.Key     = "defaults:replaceSingleTagWhileDrop"              // Bool
    static let duplicateOffset                      : UserDefaults.Key     = "defaults:duplicateOffset"                        // Int
    static let maximumPreviewLineCount              : UserDefaults.Key     = "defaults:maximumPreviewLineCount"                // Int
    static let makeSoundsAfterDoubleClickCopy       : UserDefaults.Key     = "defaults:makeSoundsAfterDoubleClickCopy"         // Bool
    
    static let screenshotSavingPath                 : UserDefaults.Key     = "defaults:screenshotSavingPath"                   // String
    
    static let pixelMatchThreshold                  : UserDefaults.Key     = "defaults:pixelMatchThreshold"                    // Double
    static let pixelMatchIncludeAA                  : UserDefaults.Key     = "defaults:pixelMatchIncludeAA"                    // Bool
    static let pixelMatchAlpha                      : UserDefaults.Key     = "defaults:pixelMatchAlpha"                        // Double
    static let pixelMatchAAColor                    : UserDefaults.Key     = "defaults:pixelMatchAAColor"                      // NSColor
    static let pixelMatchDiffColor                  : UserDefaults.Key     = "defaults:pixelMatchDiffColor"                    // NSColor
    static let pixelMatchDiffMask                   : UserDefaults.Key     = "defaults:pixelMatchDiffMask"                     // Bool
    static let pixelMatchBackgroundMode             : UserDefaults.Key     = "defaults:pixelMatchBackgroundMode"               // Bool
    
    static let enableGPUAcceleration                : UserDefaults.Key     = "defaults:enableGPUAcceleration"                  // Bool
    static let enableSyntaxHighlighting             : UserDefaults.Key     = "defaults:enableSyntaxHighlighting"               // Bool
    static let checkUpdatesAutomatically            : UserDefaults.Key     = "SUEnableAutomaticChecks"                         // Bool
    
    static let initialSimilarity                    : UserDefaults.Key     = "defaults:initialSimilarity"                      // Double
    static let sceneMaximumSmartMagnification       : UserDefaults.Key     = "defaults:sceneMaximumSmartMagnification"         // Double
    static let gridViewSizeLevel                    : UserDefaults.Key     = "defaults:gridViewSizeLevel"                      // Int
    static let gridViewAnimationSpeed               : UserDefaults.Key     = "defaults:gridViewAnimationSpeed"                 // Int
    
    static let locateExportedItemsAfterOperation    : UserDefaults.Key     = "defaults:locateExportedItemsAfterOperation"      // Bool
    
    static let disableColorAnnotation               : UserDefaults.Key     = "defaults:disableColorAnnotation"                 // Bool
    static let disableTagReordering                 : UserDefaults.Key     = "defaults:disableTagReordering"                   // Bool
    static let disableTagEditing                    : UserDefaults.Key     = "defaults:disableTagEditing"                      // Bool
    
    static let colorGridColorAnnotatorColor         : UserDefaults.Key     = "defaults:colorGridColorAnnotatorColor"           // NSColor
    static let colorGridAreaAnnotatorColor          : UserDefaults.Key     = "defaults:colorGridAreaAnnotatorColor"            // NSColor
    
}
