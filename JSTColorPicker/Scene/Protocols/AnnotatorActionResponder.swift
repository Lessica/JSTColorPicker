//
//  AnnotatorActionResponder.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/5/11.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

protocol AnnotatorActionResponder: CustomResponder {
    func quickAnnotatorAction(_ sender: Any?)
    func quickCopyAnnotatorAction(_ sender: Any?)
    func selectPreviousAnnotatorAction(_ sender: Any?)
    func selectNextAnnotatorAction(_ sender: Any?)
    func removeAnnotatorAction(_ sender: Any?)
    func listRemovableAnnotatorAction(_ sender: Any?)
}
