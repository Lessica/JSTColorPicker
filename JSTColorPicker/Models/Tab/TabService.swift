//  Copyright © 2019 Christian Tietze. All rights reserved. Distributed under the MIT License.
import Cocoa

extension Notification.Name {
    static let dropRespondingWindowChanged = Notification.Name("DropRespondingWindowChanged")
}

class TabService: TabDelegate {
    
    private var internalActiveOrder: Int = 0
    private var pendingActiveOrder: Int {
        let currentActiveOrder = internalActiveOrder
        internalActiveOrder += 1
        return currentActiveOrder
    }
    private var internalManagedWindows: [ManagedWindow] = []
    private weak var dropRespondingWindow: NSWindow?
    var managedWindows: [ManagedWindow] { internalManagedWindows.sorted(by: { $1.windowActiveOrder < $0.windowActiveOrder }) }
    
    /// Returns the main window of the managed window stack.
    /// Falls back the first element if no window is main. Note that this would
    /// likely be an internal inconsistency we gracefully handle here.
    var firstRespondingWindow: NSWindow? {
        
        // FIXME: this is a workaround for drag'n'drop feature that
        //        new document could be opened in the window where user drops ther image in
        if let respondingWindow = dropRespondingWindow {
            self.dropRespondingWindow = nil
            return respondingWindow
        }
        
        return firstManagedWindow.map({ $0.window })
    }
    
    var firstManagedWindow: ManagedWindow? {
        let mainManagedWindow = internalManagedWindows
            .first { $0.window.isMainWindow }
        
        // In case we run into the inconsistency, let it crash in debug mode so we
        // can fix our window management setup to prevent this from happening.
        // assert(mainManagedWindow != nil || internalManagedWindows.isEmpty)
        
        return (mainManagedWindow ?? managedWindows.first)
    }

    var dropRespondingObserver: NSObjectProtocol?
    
    init(initialWindowController: WindowController) {
        precondition(addManagedWindow(windowController: initialWindowController) != nil)
        dropRespondingObserver = NotificationCenter.default.addObserver(
            forName: .dropRespondingWindowChanged,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else {
                self?.dropRespondingWindow = nil
                return
            }
            self?.dropRespondingWindow = window
        }
    }

    deinit {
        if dropRespondingObserver != nil {
            NotificationCenter.default.removeObserver(dropRespondingObserver!)
            dropRespondingObserver = nil
        }
    }
    
    @discardableResult
    func addManagedWindow(windowController: WindowController) -> ManagedWindow? {
        guard let window = windowController.window else { return nil }
        let subscription = NotificationCenter.default.observe(
            name: NSWindow.willCloseNotification,
            object: window
        ) { [unowned self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self.removeManagedWindow(forWindow: window)
        }
        let management = ManagedWindow(
            windowActiveOrder: pendingActiveOrder,
            windowController: windowController,
            closingSubscription: subscription
        )

        internalManagedWindows.append(management)
        windowController.tabDelegate = self
        return management
    }
    
    func activeManagedWindow(windowController: WindowController) -> Int? {
        guard let management = internalManagedWindows.first(where: { $0.windowController === windowController }) else { return nil }
        let activeOrder = pendingActiveOrder
        management.windowActiveOrder = activeOrder
        return activeOrder
    }
    
    func removeManagedWindow(forWindow window: NSWindow) {
        internalManagedWindows.removeAll(where: { $0.window === window })
    }
    
}
