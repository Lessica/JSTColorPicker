//
//  AnnotatorSource.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol AnnotatorSource: class {
    var annotators: [Annotator] { get }
    func loadAnnotators(from content: Content) throws
    func addAnnotators(for items: [ContentItem])
    func removeAnnotators(for items: [ContentItem])
    func highlightAnnotators(for items: [ContentItem], scrollTo: Bool)
}

