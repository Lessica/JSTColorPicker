/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Application Controller object, and the NSBrowser delegate. An instance of this object is in the MainMenu.xib.
 */

@import Cocoa;
#import "FileSystemNode.h"

@interface BrowserController : NSObject <NSBrowserDelegate>

@property (nonatomic, assign, getter=isLeafItemPreviewable) IBInspectable BOOL leafItemPreviewable;
@property (readonly, assign) FileSystemNodeSortedBy sortedBy;

- (BOOL)openNode:(FileSystemNode *)clickedNode;
- (BOOL)openInternalNode:(FileSystemNode *)clickedNode;
- (BOOL)openExternalNode:(FileSystemNode *)clickedNode;

@end
