//
//  EditArrayController.swift
//  JSTColorPicker
//
//  Created by Rachel on 3/23/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

@objc
protocol EditArrayControllerDelegate: AnyObject {
    func contentsArrayWillUpdate(_ sender: EditArrayController)
    func contentsArrayDidUpdate(_ sender: EditArrayController)
}

class EditArrayController: NSArrayController {
    
    @IBOutlet @objc weak var delegate: EditArrayControllerDelegate?
    private var contentObservation: NSKeyValueObservation?
    private var contentArrayObservations: [NSKeyValueObservation]?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentObservation = observe(\.arrangedObjects, options: [.prior], changeHandler: { (target, change) in
            target.contentArrayObservations = (target.arrangedObjects as? [AssociatedKeyPath])?.map({
                [
                    $0.observe(\.name, options: [.prior], changeHandler: { keyPath, keyPathChange in
                        if keyPathChange.isPrior {
                            target.delegate?.contentsArrayWillUpdate(target)
                        } else {
                            target.delegate?.contentsArrayDidUpdate(target)
                        }
                    }),
                    $0.observe(\.type, options: [.prior], changeHandler: { keyPath, keyPathChange in
                        if keyPathChange.isPrior {
                            target.delegate?.contentsArrayWillUpdate(target)
                        } else {
                            target.delegate?.contentsArrayDidUpdate(target)
                        }
                    }),
                    $0.observe(\.value, options: [.prior], changeHandler: { keyPath, keyPathChange in
                        if keyPathChange.isPrior {
                            target.delegate?.contentsArrayWillUpdate(target)
                        } else {
                            target.delegate?.contentsArrayDidUpdate(target)
                        }
                    })
                ]
            }).flatMap({ $0 })
        })
    }
    
    override func add(_ sender: Any?) {
        delegate?.contentsArrayWillUpdate(self)
        super.add(sender)
        delegate?.contentsArrayDidUpdate(self)
    }
    
    override func insert(_ sender: Any?) {
        delegate?.contentsArrayWillUpdate(self)
        super.insert(sender)
        delegate?.contentsArrayDidUpdate(self)
    }
    
    override func remove(_ sender: Any?) {
        delegate?.contentsArrayWillUpdate(self)
        super.remove(sender)
        delegate?.contentsArrayDidUpdate(self)
    }
    
    deinit {
        debugPrint("- [EditArrayController deinit]")
    }
    
}
