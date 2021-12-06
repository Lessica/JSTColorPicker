/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A cell that can draw an image/icon and a label color.
 */

@import Cocoa;

@interface FileSystemBrowserCell : NSTextFieldCell

@property (strong) NSImage *image;
@property (strong) NSColor *labelColor;

@end
