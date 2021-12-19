//
//  Screenshot+Menu.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension Screenshot {
    
    private var associatedWindowController: WindowController? { windowControllers.first as? WindowController }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copyAll(_:))
            || menuItem.action == #selector(exportAll(_:))
        {
            guard let template = TemplateManager.shared.selectedTemplate else { return false }

            if menuItem.action == #selector(exportAll(_:)) {
                guard template.saveInPlace || template.allowedExtensions.count > 0 else { return false }
            }
        }
        return super.validateMenuItem(menuItem)
    }
    
    @IBAction private func copyAll(_ sender: Any) {
        guard let template = TemplateManager.shared.selectedTemplate else {
            presentError(ExportManager.Error.noTemplateSelected)
            return
        }
        
        if template.isAsync {
            copyAllContentItemsAsync(with: template)
        } else {
            copyAllContentItems(with: template)
        }
    }
    
    @IBAction private func exportAll(_ sender: Any) {
        guard let window = associatedWindowController?.window else { return }
        guard let template = TemplateManager.shared.selectedTemplate else {
            presentError(ExportManager.Error.noTemplateSelected)
            return
        }
        guard template.saveInPlace || template.allowedExtensions.count > 0 else {
            presentError(ExportManager.Error.noExtensionSpecified)
            return
        }

        if !template.saveInPlace {
            let panel = NSSavePanel()
            let exportOptionView = ExportPanelAccessoryView.instantiateFromNib(withOwner: self)
            panel.accessoryView = exportOptionView
            panel.nameFieldStringValue = String(format: NSLocalizedString("%@ Exported %ld Items", comment: "exportAll(_:)"), displayName ?? "", content?.items.count ?? 0)
            panel.allowedFileTypes = template.allowedExtensions
            panel.beginSheetModal(for: window) { [unowned self] (resp) in
                if resp == .OK {
                    if let url = panel.url {
                        if template.isAsync {
                            self.exportAllContentItemsAsync(
                                to: url,
                                with: template,
                                byLocatingAfterOperation: exportOptionView?.locateAfterOperation ?? false
                            )
                        } else {
                            self.exportAllContentItems(
                                to: url,
                                with: template,
                                byLocatingAfterOperation: exportOptionView?.locateAfterOperation ?? false
                            )
                        }
                    }
                }
            }
        } else {
            if template.isAsync {
                self.exportAllContentItemsAsyncInPlace(with: template)
            } else {
                self.exportAllContentItemsInPlace(with: template)
            }
        }
    }
    
    private func copyAllContentItems(with template: Template) {
        do {
            try export.copyAllContentItems(with: template)
        } catch {
            presentError(error)
        }
    }

    private func copyAllContentItemsAsync(with template: Template) {
        guard let window = associatedWindowController?.window else { return }
        extractContentItems(in: window, with: template) { [unowned self] (tmpl) in
            try export.copyAllContentItems(with: tmpl)
        }
    }
    
    private func exportAllContentItems(
        to url: URL,
        with template: Template,
        byLocatingAfterOperation locate: Bool
    ) {
        do {
            try export.exportAllContentItems(to: url, with: template)
            if locate {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            presentError(error)
        }
    }

    private func exportAllContentItemsInPlace(with template: Template) {
        do {
            try export.exportAllContentItemsInPlace(with: template)
        } catch {
            presentError(error)
        }
    }

    private func exportAllContentItemsAsync(
        to url: URL,
        with template: Template,
        byLocatingAfterOperation locate: Bool
    ) {
        guard let window = associatedWindowController?.window else { return }
        extractContentItems(in: window, with: template) { [unowned self] (tmpl) in
            try self.export.exportAllContentItems(to: url, with: tmpl)
        } completionHandler: { (succeed) in
            if succeed && locate {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }

    }

    private func exportAllContentItemsAsyncInPlace(with template: Template) {
        guard let window = associatedWindowController?.window else { return }
        extractContentItems(in: window, with: template) { [unowned self] (tmpl) in
            try self.export.exportAllContentItemsInPlace(with: tmpl)
        }
    }
}
