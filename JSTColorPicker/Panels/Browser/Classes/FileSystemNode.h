/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 An abstract wrapper node around the file system.
 */

@import Cocoa;

typedef enum : NSUInteger {
    FileSystemNodeSortedByName = 0,
    FileSystemNodeSortedByKind,
    FileSystemNodeSortedByDateLastOpened,
    FileSystemNodeSortedByDateAdded,
    FileSystemNodeSortedByDateModified,
    FileSystemNodeSortedByDateCreated,
    FileSystemNodeSortedBySize,
} FileSystemNodeSortedBy;

// This is a simple wrapper around the file system. Its main purpose is to cache children.
@interface FileSystemNode : NSObject

// The designated initializer
- (instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;

@property (readonly) NSURL *URL;
@property (readonly, copy) NSString *displayName;
@property (readonly, strong) NSImage *icon;
@property (readonly, strong) NSImage *previewImage;
@property (readonly, strong) NSArray <FileSystemNode *> *children;
@property (readonly, assign) FileSystemNodeSortedBy childrenSortedBy;
@property (readonly) BOOL isDirectory;
@property (readonly) BOOL isPackage;
@property (readonly) BOOL isSymbolicLink;
@property (readonly) BOOL isLeafItem;
@property (readonly, strong) NSColor *labelColor;
@property (readonly) NSUInteger size;
@property (readonly, strong) NSString *formattedFileSize;
@property (readonly, strong) NSString *contentType;
@property (readonly, strong) NSString *documentKind;
@property (readonly, strong) NSDate *creationDate;
@property (readonly, strong) NSDate *modificationDate;
@property (readonly, strong) NSDate *addedDate;
@property (readonly, strong) NSDate *lastUsedDate;

- (void)setChildrenSortedBy:(FileSystemNodeSortedBy)childrenSortedBy;
- (void)invalidateChildren;

@end
