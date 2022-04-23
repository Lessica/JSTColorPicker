/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View Controller subclass used for our preview pane in NSBrowser.
 */

#import "PreviewViewController.h"
#import "FileSystemNode.h"
#import <AppKit/NSDocumentController.h>

#import "JSTColorPicker-Swift.h"


@implementation PreviewViewController

- (void)mouseDown:(NSEvent *)theEvent {
    
    [super mouseDown:theEvent];
    
    // check for double click
    if ([theEvent clickCount] > 1) {
        // Find the clicked item and open it in Finder
        FileSystemNode *clickedNode = self.representedObject;
        
        BOOL handleBySelf = NO;
        if (@available(macOS 12.0, *)) {
            NSArray <NSURL *> *handlerURLs = [[NSWorkspace sharedWorkspace] URLsForApplicationsToOpenURL:clickedNode.URL];
            if ([handlerURLs containsObject:[[NSBundle mainBundle] bundleURL]]) {
                handleBySelf = YES;
            }
        } else {
            // Fallback on earlier versions
            NSArray <NSString *> *handlerIdentifiers = CFBridgingRelease(LSCopyAllRoleHandlersForContentType((__bridge CFStringRef _Nonnull)(clickedNode.contentType), kLSRolesEditor));
            if ([handlerIdentifiers containsObject:[[NSBundle mainBundle] bundleIdentifier]]) {
                handleBySelf = YES;
            }
        }
        if (handleBySelf) {
            [(ScreenshotController *)[ScreenshotController sharedDocumentController] openScreenshotWithContentsOfURL:clickedNode.URL display:YES];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:clickedNode.URL];
        }
    }
}

@end
