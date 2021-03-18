//
//  Content.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Content: NSObject, Codable {
    
    enum Error: LocalizedError {
        
        case itemExists(item: CustomStringConvertible)
        case itemDoesNotExist(item: CustomStringConvertible)
        case itemDoesNotExistPartial
        case itemNotValid(item: CustomStringConvertible)
        case itemOutOfRange(item: CustomStringConvertible, range: CustomStringConvertible)
        case itemReachLimit(totalSpace: Int)
        case itemReachLimitBatch(moreSpace: Int)
        case itemConflict(item1: CustomStringConvertible, item2: CustomStringConvertible)
        case notLoaded
        case notWritable
        case userAborted
        
        var failureReason: String? {
            switch self {
            case let .itemExists(item):
                return String(format: NSLocalizedString("This item %@ already exists.", comment: "Content.Error"), item.description)
            case let .itemDoesNotExist(item):
                return String(format: NSLocalizedString("This item %@ does not exist.", comment: "Content.Error"), item.description)
            case .itemDoesNotExistPartial:
                return NSLocalizedString("Some of these items do not exist.", comment: "Content.Error")
            case let .itemNotValid(item):
                return String(format: NSLocalizedString("This requested item %@ is not valid.", comment: "Content.Error"), item.description)
            case let .itemOutOfRange(item, range):
                return String(format: NSLocalizedString("The requested item %@ is out of the document range %@.", comment: "Content.Error"), item.description, range.description)
            case let .itemReachLimit(totalSpace):
                return String(format: NSLocalizedString("Maximum item count %d reached.", comment: "Content.Error"), totalSpace)
            case let .itemReachLimitBatch(moreSpace):
                return String(format: NSLocalizedString("This operation requires %d more spaces.", comment: "Content.Error"), moreSpace)
            case let .itemConflict(item1, item2):
                return String(format: NSLocalizedString("The requested item %@ conflicts with another item %@ in the document.", comment: "Content.Error"), item1.description, item2.description)
            case .notLoaded:
                return NSLocalizedString("No document loaded.", comment: "Content.Error")
            case .notWritable:
                return NSLocalizedString("Document locked.", comment: "Content.Error")
            case .userAborted:
                return NSLocalizedString("User aborted.", comment: "Content.Error")
            }
        }
        
    }
    
    public var items       : [ContentItem]
    public var lazyColors  : [PixelColor]    { items.lazy.compactMap({ $0 as? PixelColor }) }
    public var lazyAreas   : [PixelArea]     { items.lazy.compactMap({ $0 as? PixelArea })  }
    
    override init() {
        items = [ContentItem]()
        super.init()
    }
    
    required init?(coder: NSCoder) {
        guard let items = coder.decodeObject(forKey: "items") as? [ContentItem] else { return nil }
        self.items = items
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([ContentItem].self, forKey: .items)
    }
    
}

extension Content: NSSecureCoding {

    class var supportsSecureCoding: Bool { true }

    enum CodingKeys: String, CodingKey {
        case items
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(items, forKey: "items")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
    }
    
}
