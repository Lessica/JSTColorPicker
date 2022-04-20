//
//  PaddleLicenseActivationWindowController.swift
//  JSTColorPickerSparkle
//
//  Created by Rachel on 4/20/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class PaddleLicenseActivationWindowController: NSWindowController {
    
    private var viewController: PaddleLicenseActivationViewController
    {
        contentViewController as! PaddleLicenseActivationViewController
    }
    
    var emailAddress: String {
        return viewController.emailAddress
    }
    
    var licenseCode: String {
        return viewController.licenseCode
    }
    
}
