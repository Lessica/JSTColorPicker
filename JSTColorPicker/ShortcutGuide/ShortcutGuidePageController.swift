//
//  ShortcutGuidePageController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/3/25.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

internal class ShortcutGuidePageController: NSPageController, NSPageControllerDelegate {

    @IBOutlet var visualEffectView: NSVisualEffectView!
    @IBOutlet var pageControl: ShortcutGuidePageControl!

    var items: [ShortcutItem]?
    var groups: [ShortcutItemGroup]? { arrangedObjects as? [ShortcutItemGroup] }
    func group(with identifier: String) -> ShortcutItemGroup? {
        guard let groups = groups else {
            return nil
        }
        return groups.first(where: { $0.identifier == identifier })
    }

    private var pageConstraints: [NSLayoutConstraint]?

    func prepareForPresentation() {
        if let items = items, items.count > 0 {
            arrangedObjects = ShortcutItemGroup.splitItemsIntoGroups(items, maximumCount: 16)
        } else {
            arrangedObjects = [ ShortcutItemGroup.empty ]
        }
        selectedIndex = 0
        pageControl.numberOfPages = arrangedObjects.count
        pageControl.currentPage = 0
    }

    private func maskImage(cornerRadius: CGFloat) -> NSImage {
        let edgeLength = 2.0 * cornerRadius + 1.0
        let maskImage = NSImage(size: NSSize(width: edgeLength, height: edgeLength), flipped: false) { rect in
            let bezierPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.set()
            bezierPath.fill()
            return true
        }
        maskImage.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        maskImage.resizingMode = .stretch
        return maskImage
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        delegate = self

        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.maskImage = maskImage(cornerRadius: 16.0)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        view.window?.contentView = visualEffectView
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        transitionStyle = .horizontalStrip
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        if let superview = view.superview {
            if let pageConstraints = pageConstraints {
                NSLayoutConstraint.deactivate(pageConstraints)
                self.pageConstraints = nil
            }
            let constraints = [
                view.topAnchor.constraint(equalTo: superview.topAnchor),
                view.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                view.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            ]
            NSLayoutConstraint.activate(constraints)
            pageConstraints = constraints
        }
    }

    func pageController(_ pageController: NSPageController, prepare viewController: NSViewController, with object: Any?) {
        guard object != nil, let ctrl = viewController as? ShortcutGuideViewController else { return }
        ctrl.updateDisplayWithItems((object as! ShortcutItemGroup).items)
        ctrl.isSinglePage = arrangedObjects.count == 1
        ctrl.view.needsUpdateConstraints = true
    }

    func pageController(_ pageController: NSPageController, viewControllerForIdentifier identifier: NSPageController.ObjectIdentifier) -> NSViewController {
        return self.storyboard!.instantiateController(withIdentifier: "ShortcutGuideViewController") as! ShortcutGuideViewController
    }

    func pageController(_ pageController: NSPageController, identifierFor object: Any) -> NSPageController.ObjectIdentifier {
        return (object as! ShortcutItemGroup).identifier!
    }

    func pageControllerDidEndLiveTransition(_ pageController: NSPageController) {
        completeTransition()
        pageControl.currentPage = selectedIndex
    }

    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        NSCursor.arrow.set()
    }

}
