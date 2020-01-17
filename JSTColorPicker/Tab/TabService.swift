//  Copyright © 2019 Christian Tietze. All rights reserved. Distributed under the MIT License.
import Cocoa

extension NSNotification.Name {
    static let respondingWindowChanged = Notification.Name("RespondingWindowChanged")
}

class TabService: TabDelegate {
    
    fileprivate(set) var managedWindows: [ManagedWindow] = []
    fileprivate weak var respondingWindow: NSWindow?
    
    /// Returns the main window of the managed window stack.
    /// Falls back the first element if no window is main. Note that this would
    /// likely be an internal inconsistency we gracefully handle here.
    var firstRespondingWindow: NSWindow? {
        
        // FIXME: this is a workaround for drag'n'drop feature that
        //        new document could be opened in the window where user drops ther image in
        if let respondingWindow = respondingWindow {
            self.respondingWindow = nil
            return respondingWindow
        }
        
        let mainManagedWindow = managedWindows
            .first { $0.window.isMainWindow }
        
        // In case we run into the inconsistency, let it crash in debug mode so we
        // can fix our window management setup to prevent this from happening.
        assert(mainManagedWindow != nil || managedWindows.isEmpty)
        
        return (mainManagedWindow ?? managedWindows.first)
            .map { $0.window }
    }
    
    init(initialWindowController: WindowController) {
        precondition(addManagedWindow(windowController: initialWindowController) != nil)
        NotificationCenter.default.addObserver(forName: .respondingWindowChanged, object: nil, queue: nil) { [unowned self] notification in
            guard let window = notification.object as? NSWindow else {
                self.respondingWindow = nil
                return
            }
            self.respondingWindow = window
        }
    }
    
    func addManagedWindow(windowController: WindowController) -> ManagedWindow? {
        guard let window = windowController.window else { return nil }
        let subscription = NotificationCenter.default.observe(name: NSWindow.willCloseNotification, object: window) { [unowned self] notification in
            guard let window = notification.object as? NSWindow else { return }
            self.removeManagedWindow(forWindow: window)
        }
        let management = ManagedWindow(
            windowController: windowController,
            window: window,
            closingSubscription: subscription)
        managedWindows.append(management)
        windowController.tabDelegate = self
        return management
    }
    
    func removeManagedWindow(forWindow window: NSWindow) {
        managedWindows.removeAll(where: { $0.window === window })
    }
    
    deinit {
        debugPrint("- [TabService deinit]")
    }
    
}
