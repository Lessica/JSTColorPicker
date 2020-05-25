//
//  TagListController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/24.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class TagListController: NSViewController, NSTableViewDelegate {
    
    @IBOutlet var managedObjectContext: NSManagedObjectContext!
    @IBOutlet var tagCtrl: NSArrayController!
    @IBOutlet var tagMenu: NSMenu!
    @IBOutlet weak var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tagCtrl.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        setupPersistentStore(fetchInitialTags: { () -> ([(String, String)]) in
            return [
                
                /* Controls */
                ("Button",         "#171E6D"),
                ("Switch",         "#1E3388"),
                ("Slider",         "#27539B"),
                ("Checkbox",       "#3073AE"),
                ("Radio",          "#3993C2"),
                ("TextField",      "#42B3D5"),
                ("Rate",           "#75C6D1"),
                ("BackTop",        "#A9DACC"),
                
                /* Displays */
                ("Label",          "#044E48"),
                ("Badge",          "#06746B"),
                ("Media",          "#20876B"),
                ("Box",            "#6A9A48"),
                ("Hud",            "#B5AC23"),
                ("Keyboard",       "#E6B80B"),
                ("Progress",       "#FACA3E"),
                ("Spin",           "#FFDF80"),
                
                /* Layouts */
                ("StatusBar",      "#661900"),
                ("TabBar",         "#B22C00"),
                ("NavigationBar",  "#E6450F"),
                ("Skeleton",       "#FF6500"),
                ("Notification",   "#FF8C00"),
                
                /* Status */
                ("Disabled",       "#657899"),
                ("Active",         "#1C314E"),
                
            ]
        }) { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    fileprivate func setupPersistentStore(fetchInitialTags: @escaping () -> ([(String, String)]), completionClosure: @escaping () -> ()) {
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
                        
                        var idx = 1
                        fetchInitialTags().forEach { (tag) in
                            let obj = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: self.managedObjectContext) as! Tag
                            obj.order = Int64(idx)
                            obj.name = tag.0
                            obj.colorHex = tag.1
                            idx += 1
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
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return TagListRowView()
    }
    
}
