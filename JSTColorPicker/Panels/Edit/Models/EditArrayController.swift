//
//  EditArrayController.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/23/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

@objc
enum EditArrayControllerUpdateType: Int {
    case add
    case insert
    case remove
    case update
    case direct
}

@objc
protocol EditArrayControllerDelegate: AnyObject {
    func contentArrayWillUpdate(_ sender: EditArrayController, type: EditArrayControllerUpdateType)
    func contentArrayDidUpdate(_ sender: EditArrayController, type: EditArrayControllerUpdateType)
}

final class EditArrayController: NSArrayController {
    
    @IBOutlet @objc weak var delegate: EditArrayControllerDelegate?
    private var contentObservation: NSKeyValueObservation?
    private var contentArrayObservations: [NSKeyValueObservation]?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentObservation = observe(\.arrangedObjects, options: [.prior], changeHandler: { (target, change) in
            target.contentArrayObservations = (target.arrangedObjects as? [AssociatedKeyPath])?.map({
                [
                    $0.observe(\.name, options: [.prior], changeHandler: { keyPath, keyPathChange in
                        if keyPath.allowsKVONotification {
                            if keyPathChange.isPrior {
                                target.delegate?.contentArrayWillUpdate(target, type: .update)
                            } else {
                                target.delegate?.contentArrayDidUpdate(target, type: .update)
                            }
                        }
                    }),
                    $0.observe(\.type, options: [.prior], changeHandler: { keyPath, keyPathChange in
                        if keyPath.allowsKVONotification {
                            if keyPathChange.isPrior {
                                target.delegate?.contentArrayWillUpdate(target, type: .update)
                            } else {
                                target.delegate?.contentArrayDidUpdate(target, type: .update)
                            }
                        }
                    }),
                    $0.observe(\.value, options: [.prior], changeHandler: { keyPath, keyPathChange in
                        if keyPath.allowsKVONotification {
                            if keyPathChange.isPrior {
                                target.delegate?.contentArrayWillUpdate(target, type: .update)
                            } else {
                                target.delegate?.contentArrayDidUpdate(target, type: .update)
                            }
                        }
                    })
                ]
            }).flatMap({ $0 })
        })
    }
    
    var contentUpdateType: EditArrayControllerUpdateType?
    override var content: Any? {
        get {
            super.content
        }
        set {
            delegate?.contentArrayWillUpdate(self, type: contentUpdateType ?? .direct)
            super.content = newValue
            delegate?.contentArrayDidUpdate(self, type: contentUpdateType ?? .direct)
            contentUpdateType = nil
        }
    }
    
    override func addObject(_ object: Any) {
        super.addObject(object)
    }
    
    override func add(contentsOf objects: [Any]) {
        super.add(contentsOf: objects)
    }
    
    override func insert(_ object: Any, atArrangedObjectIndex index: Int) {
        delegate?.contentArrayWillUpdate(self, type: .insert)
        super.insert(object, atArrangedObjectIndex: index)
        delegate?.contentArrayDidUpdate(self, type: .insert)
    }
    
    override func insert(contentsOf objects: [Any], atArrangedObjectIndexes indexes: IndexSet) {
        super.insert(contentsOf: objects, atArrangedObjectIndexes: indexes)
    }
    
    override func removeObject(_ object: Any) {
        super.removeObject(object)
    }
    
    override func remove(contentsOf objects: [Any]) {
        super.remove(contentsOf: objects)
    }
    
    override func remove(atArrangedObjectIndex index: Int) {
        super.remove(atArrangedObjectIndex: index)
    }
    
    override func remove(atArrangedObjectIndexes indexes: IndexSet) {
        delegate?.contentArrayWillUpdate(self, type: .remove)
        super.remove(atArrangedObjectIndexes: indexes)
        delegate?.contentArrayDidUpdate(self, type: .remove)
    }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
}
