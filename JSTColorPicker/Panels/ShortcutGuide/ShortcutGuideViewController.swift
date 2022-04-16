//
//  ShortcutGuideViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 11/1/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class ShortcutGuideViewController: NSViewController {
    
    @IBOutlet weak var nothingLabel        : NSTextField!
    @IBOutlet weak var stackView           : NSStackView!
    @IBOutlet weak var pageStackView       : NSStackView!
    @IBOutlet weak var columnStackView1    : NSStackView!
    @IBOutlet weak var columnDivider       : NSBox!
    @IBOutlet weak var columnStackView2    : NSStackView!

    @IBOutlet weak var topConstraint       : NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint    : NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint  : NSLayoutConstraint!
    
    @IBOutlet weak var itemWrapperView1    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView2    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView3    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView4    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView5    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView6    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView7    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView8    : ShortcutItemView!
    
    @IBOutlet weak var itemWrapperView9    : ShortcutItemView!
    @IBOutlet weak var itemWrapperView10   : ShortcutItemView!
    @IBOutlet weak var itemWrapperView11   : ShortcutItemView!
    @IBOutlet weak var itemWrapperView12   : ShortcutItemView!
    @IBOutlet weak var itemWrapperView13   : ShortcutItemView!
    @IBOutlet weak var itemWrapperView14   : ShortcutItemView!
    @IBOutlet weak var itemWrapperView15   : ShortcutItemView!
    @IBOutlet weak var itemWrapperView16   : ShortcutItemView!
    
    private lazy var itemWrappers: [ShortcutItemView] = {
        var wrappers = [ShortcutItemView]()
        wrappers.append(itemWrapperView1)
        wrappers.append(itemWrapperView2)
        wrappers.append(itemWrapperView3)
        wrappers.append(itemWrapperView4)
        wrappers.append(itemWrapperView5)
        wrappers.append(itemWrapperView6)
        wrappers.append(itemWrapperView7)
        wrappers.append(itemWrapperView8)
        wrappers.append(itemWrapperView9)
        wrappers.append(itemWrapperView10)
        wrappers.append(itemWrapperView11)
        wrappers.append(itemWrapperView12)
        wrappers.append(itemWrapperView13)
        wrappers.append(itemWrapperView14)
        wrappers.append(itemWrapperView15)
        wrappers.append(itemWrapperView16)
        return wrappers
    }()

    var isSinglePage: Bool = false
    var isEmptyPage: Bool { !nothingLabel.isHidden }
    private var pageConstraints: [NSLayoutConstraint]?

    override func awakeFromNib() {
        super.awakeFromNib()
        view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateDisplayWithItems([])
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()

        var constraints = [NSLayoutConstraint]()
        if let superview = view.superview {
            constraints += [
                view.topAnchor.constraint(equalTo: superview.topAnchor),
                view.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            ]
        }

        if isEmptyPage {
            topConstraint.constant = 20
            bottomConstraint.constant = 20
            trailingConstraint.constant = 20
        } else if isSinglePage {
            topConstraint.constant = 32
            bottomConstraint.constant = 32
            trailingConstraint.constant = 32
        } else {
            topConstraint.constant = 24
            bottomConstraint.constant = 40
            trailingConstraint.constant = 32
        }

        if isEmptyPage {
            constraints += [
                view.bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
                view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 20)
            ]
        } else if isSinglePage {
            constraints += [
                view.bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 32),
                view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 32)
            ]
        }

        if let pageConstraints = pageConstraints {
            NSLayoutConstraint.deactivate(pageConstraints)
            self.pageConstraints = nil
        }

        NSLayoutConstraint.activate(constraints)
        pageConstraints = constraints
    }

    func updateDisplayWithItems(_ items: [ShortcutItem]) {
        nothingLabel.isHidden = items.count != 0
        pageStackView.isHidden = items.count == 0
        columnStackView1.isHidden = items.count == 0
        columnDivider.isHidden = items.count <= 8
        columnStackView2.isHidden = items.count <= 8
        var itemIdx = 0
        for itemWrapper in itemWrappers {
            itemWrapper.isHidden = items.count <= itemIdx
            if items.count > itemIdx {
                itemWrapper.updateDisplayWithItem(items[itemIdx])
            } else {
                itemWrapper.resetDisplay()
            }
            itemIdx += 1
        }
    }

}
