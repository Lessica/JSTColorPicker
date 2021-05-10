//
//  ItemPreviewResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/7/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum ItemPreviewStage {
    case none
    case begin
    case inProgress
    case end
}

protocol ItemPreviewSender {
    var previewStage: ItemPreviewStage { get }
}

protocol ItemPreviewResponder: AnyObject {
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool)
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool)
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool)
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat)
    func previewActionRaw(_ sender: ItemPreviewSender?, withEvent event: NSEvent)
}
