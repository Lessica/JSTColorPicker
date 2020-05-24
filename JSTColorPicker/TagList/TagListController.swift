//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListController: NSViewController {
    
    @IBOutlet var managedObjectContext: NSManagedObjectContext!
    @IBOutlet var tagCtrl: NSArrayController!
    @IBOutlet weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        setupPersistentStore(fetchInitialTags: { () -> ([(String, String, String)]) in
            return [
                
                /* Controls */
                ("Button",         "button",          "#269A99"),
                ("Switch",         "switch",          "#5AD8A6"),
                ("Slider",         "slider",          "#BDEFDB"),
                ("Checkbox",       "checkbox",        "#FF9D4D"),
                ("Radio",          "radio",           "#FFD8B8"),
                ("TextField",      "textfield",       "#BDD2FD"),
                ("Rate",           "rate",            "#F6BD16"),
                ("BackTop",        "backtop",         "#FBE5A2"),
                
                /* Status */
                ("Disabled",       "disabled",        "#C2C8D5"),
                ("Active",         "active",          "#5D7092"),
                
                /* Displays */
                ("Label",          "label",           "#5B8FF9"),
                ("Badge",          "badge",           "#E8684A"),
                ("Media",          "media",           "#9270CA"),
                ("Alert",          "alert",           "#F6C3B7"),
                ("Keyboard",       "keyboard",        "#D3C6EA"),
                ("Progress",       "progress",        "#6DC8EC"),
                ("Spin",           "spin",            "#B6E3F5"),
                
                /* Layouts */
                ("TabBar",         "tabbar",          "#FF99C3"),
                ("NavigationBar",  "navbar",          "#FFD6E7"),
                ("Skeleton",       "skeleton",        "#AAD8D8"),
                ("Notification",   "notification",    "#269A99"),
                
            ]
        }) { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    fileprivate func setupPersistentStore(fetchInitialTags: @escaping () -> ([(String, String, String)]), completionClosure: @escaping () -> ()) {
        guard let tagModelURL = Bundle.main.url(forResource: "TagList", withExtension: "momd") else {
            fatalError("error loading model from bundle")
        }
        
        guard let tagModel = NSManagedObjectModel(contentsOf: tagModelURL) else {
            fatalError("error initializing model from \(tagModelURL)")
        }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: tagModel)
        managedObjectContext.persistentStoreCoordinator = coordinator
        
        let queue = DispatchQueue.global(qos: .background)
        
        queue.async { [weak self] in
            
            guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
                fatalError("unable to resolve library directory")
            }
            
            do {
                
                let storeURL = docURL.appendingPathComponent("JSTColorPicker/TagList.sqlite")
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
                } else {
                    
                    try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
                    
                    if let self = self {
                        
                        fetchInitialTags().forEach { (tag) in
                            let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: self.managedObjectContext) as! Tag
                            obj.label = tag.0
                            obj.name = tag.1
                            obj.colorHex = tag.2
                        }
                        
                        do {
                            try self.managedObjectContext.save()
                        } catch {
                            fatalError("failure to save context: \(error)")
                        }
                        
                    }
                    
                }
                
                DispatchQueue.main.sync(execute: completionClosure)
            }
            catch let error {
                fatalError("error migrating store: \(error)")
            }
            
        }
    }
    
}
