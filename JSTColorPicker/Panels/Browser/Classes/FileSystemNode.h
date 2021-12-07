/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 An abstract wrapper node around the file system.
 */

@import Cocoa;

// This is a simple wrapper around the file system. Its main purpose is to cache children.
@interface FileSystemNode : NSObject

// The designated initializer
- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;

@property (readonly) NSURL *URL;
@property (readonly, copy) NSString *displayName;
@property (readonly, strong) NSImage *icon;
@property (readonly, strong) NSArray *children;
@property (readonly) BOOL isDirectory;
@property (readonly) BOOL isPackage;
@property (readonly, strong) NSColor *labelColor;
@property (readonly) NSUInteger size;
@property (readonly, strong) NSString *formattedFileSize;
@property (readonly, strong) NSString *contentType;
@property (readonly, strong) NSString *documentKind;
@property (readonly, strong) NSDate *creationDate;
@property (readonly, strong) NSDate *modificationDate;
@property (readonly, strong) NSDate *lastUsedDate;

- (void)invalidateChildren;

@end
