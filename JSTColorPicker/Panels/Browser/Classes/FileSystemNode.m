/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 An abstract wrapper node around the file system.
 */

#import "FileSystemNode.h"
#import <QuickLook/QuickLook.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSScreen.h>

@interface FileSystemNode ()

@property (strong) NSURL *URL;
@property (assign) BOOL childrenDirty;
@property (strong) NSArray *internalChildren;

@end


#pragma mark -

@implementation FileSystemNode

@dynamic displayName;
@dynamic children;
@dynamic isDirectory;
@dynamic labelColor;
@dynamic documentKind;
@dynamic size;
@dynamic formattedFileSize;
@dynamic creationDate;
@dynamic modificationDate;
@dynamic addedDate;
@dynamic lastUsedDate;
@synthesize icon = _icon;
@synthesize previewImage = _previewImage;

- (instancetype)init {
    NSAssert(NO, @"Invalid use of init; use initWithURL to create FileSystemNode");
    return [self init];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self != nil) {
        _URL = url;
    }
    return self;
}

+ (instancetype)nodeWithURL:(NSURL *)url {
    FileSystemNode *node = [[FileSystemNode alloc] initWithURL:url];
    return node;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ - %@", super.description, self.URL];
}

- (NSString *)displayName {
    NSString *displayName = @"";
    NSError *error = nil;

    BOOL success = [self.URL getResourceValue:&displayName forKey:NSURLLocalizedNameKey error:&error];
    
    // if we got a no value for the localized name, we will try the non-localized name
    if (success && displayName.length > 0) {
        [self.URL getResourceValue:&displayName forKey:NSURLNameKey error:&error];
    }
    else {
        // can't find resource value for the display name, use the localizedDescription as last resort
        return error.localizedDescription;
    }
    
    return displayName;
}

- (NSImage *)icon {
    if (!_icon) {
        _icon = [self previewImageWithSize:CGSizeMake(32, 32) isIcon:YES];
    }
    return _icon;
}

- (NSImage *)previewImage {
    if (!_previewImage) {
        _previewImage = [self previewImageWithSize:CGSizeMake(384, 384) isIcon:NO];
    }
    return _previewImage;
}

- (NSImage *)previewImageWithSize:(CGSize)size isIcon:(BOOL)icon {
    NSDictionary *opts = @{
        (__bridge NSString *)kQLThumbnailOptionIconModeKey: @(icon),
        (__bridge NSString *)kQLThumbnailOptionScaleFactorKey: @([[NSScreen mainScreen] backingScaleFactor]),
    };

    NSImage *image = nil;
    if ([self isImage]) {
        CGImageRef ref = QLThumbnailImageCreate(kCFAllocatorDefault, (__bridge CFURLRef)(self.URL), size, (__bridge CFDictionaryRef)(opts));
        if (ref != NULL) {
            // Take advantage of NSBitmapImageRep's -initWithCGImage: initializer, new in Leopard,
            // which is a lot more efficient than copying pixel data into a brand new NSImage.
            // Thanks to Troy Stephens @ Apple for pointing this new method out to me.
            NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithCGImage:(CGImageRef)ref];
            image = [[NSImage alloc] initWithSize:bitmapImageRep.size];
            [image addRepresentation:bitmapImageRep];

            CFRelease(ref);
        }
    }

    if (!image) {
        image = [[NSWorkspace sharedWorkspace] iconForFile:(self.URL).path];
    }

    return image;
}

- (NSString *)documentKind {
    NSString *kindStr;
    [self.URL getResourceValue:&kindStr forKey:NSURLLocalizedTypeDescriptionKey error:nil];
    return kindStr;
}

- (NSDate *)creationDate {
    NSDate *dateValue;
    [self.URL getResourceValue:&dateValue forKey:NSURLCreationDateKey error:nil];
    return dateValue;
}

- (NSDate *)modificationDate {
    NSDate *dateValue;
    [self.URL getResourceValue:&dateValue forKey:NSURLContentModificationDateKey error:nil];
    return dateValue;
}

- (NSDate *)addedDate {
    MDItemRef itemRef = MDItemCreateWithURL(nil, (CFURLRef)self.URL);
    if (itemRef) {
        NSDate *addedDate = CFBridgingRelease(MDItemCopyAttribute(itemRef, kMDItemDateAdded));
        CFRelease(itemRef);
        return addedDate;
    }
    return nil;
}

- (NSDate *)lastUsedDate {
    MDItemRef itemRef = MDItemCreateWithURL(nil, (CFURLRef)self.URL);
    if (itemRef) {
        NSDate *lastUsedDate = CFBridgingRelease(MDItemCopyAttribute(itemRef, kMDItemLastUsedDate));
        CFRelease(itemRef);
        return lastUsedDate;
    }
    return nil;
}

- (NSUInteger)size {
    NSNumber *sizeValue;
    [self.URL getResourceValue:&sizeValue forKey:NSURLFileSizeKey error:nil];
    return [sizeValue unsignedIntegerValue];
}

- (NSString *)formattedFileSize {
    NSString *sizeStr;
    sizeStr = [NSByteCountFormatter stringFromByteCount:[self size] countStyle:NSByteCountFormatterCountStyleFile];
    return sizeStr;
}

- (NSString *)contentType {
    UTType *typeStr;
    [self.URL getResourceValue:&typeStr forKey:NSURLContentTypeKey error:nil];
    return [(NSObject *)typeStr performSelector:@selector(identifier)];  // OC is dead
}

- (BOOL)isImage {
    return UTTypeConformsTo((__bridge CFStringRef _Nonnull)(self.contentType), kUTTypeImage);
}

- (BOOL)isDirectory {
    id value = nil;
    [self.URL getResourceValue:&value forKey:NSURLIsDirectoryKey error:nil];
    return [value boolValue];
}

- (BOOL)isPackage {
    id value = nil;
    [self.URL getResourceValue:&value forKey:NSURLIsPackageKey error:nil];
    return [value boolValue];
}

- (BOOL)isSymbolicLink {
    id value = nil;
    [self.URL getResourceValue:&value forKey:NSURLIsSymbolicLinkKey error:nil];
    return [value boolValue];
}

- (BOOL)isLeafItem {
    if (self.isSymbolicLink) {
        NSURL *realURL = [self.URL URLByResolvingSymlinksInPath];
        if ([self.URL isEqual:realURL]) {
            return YES;
        }
        return [[FileSystemNode nodeWithURL:realURL] isLeafItem];
    }
    return !self.isDirectory || self.isPackage;
}

- (NSColor *)labelColor {
    id value = nil;
    [self.URL getResourceValue:&value forKey:NSURLLabelColorKey error:nil];
    return value;
}

// We are equal if we represent the same URL. This allows children to reuse the same instances.
//
- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[FileSystemNode class]]) {
        FileSystemNode *other = (FileSystemNode *)object;
        return [other.URL isEqual:self.URL];
    } else {
        return NO;
    }
}

- (NSUInteger)hash {
    return self.URL.hash;
}

- (NSArray *)children {
    if (self.internalChildren == nil || self.childrenDirty) {
        // This logic keeps the same pointers around, if possible.
        NSMutableArray *newChildren = [NSMutableArray array];
        
        CFURLEnumeratorRef enumerator = CFURLEnumeratorCreateForDirectoryURL(NULL, (CFURLRef)[self.URL URLByResolvingSymlinksInPath], kCFURLEnumeratorSkipInvisibles, (CFArrayRef)[NSArray array]);
        CFURLRef childURL = nil;
        CFURLEnumeratorResult enumeratorResult;
        do {
                enumeratorResult = CFURLEnumeratorGetNextURL(enumerator, &childURL, NULL);
                if (enumeratorResult == kCFURLEnumeratorSuccess) {
                    FileSystemNode *node = [[FileSystemNode alloc] initWithURL:(__bridge NSURL *)childURL];
                    if (self.internalChildren != nil) {
                        NSInteger oldIndex = [self.internalChildren indexOfObjectPassingTest:^BOOL(FileSystemNode * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            return [obj.URL isEqual:(__bridge NSURL *)childURL];
                        }];
                        if (oldIndex != NSNotFound) {
                            // Use the same pointer value, if possible
                            node = (self.internalChildren)[oldIndex];
                        }
                    }
                    [newChildren addObject:node];
                } else if (enumeratorResult == kCFURLEnumeratorError) {
                    // A possible enhancement would be to present error-based items to the user.
                }
        } while (enumeratorResult != kCFURLEnumeratorEnd);
        
        CFRelease(enumerator);
        _childrenDirty = NO;
        
        // Now sort them
        _internalChildren = [newChildren sortedArrayUsingComparator:[self childrenSortedByNSComparator]];
    }
    
    return self.internalChildren;
}

- (NSComparator)childrenSortedByNSComparator {
    if (self.childrenSortedBy == FileSystemNodeSortedByKind) {
        return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
            NSString *objAttr = [obj1 documentKind];
            NSString *obj2Attr = [obj2 documentKind];
            NSComparisonResult result = [objAttr compare:obj2Attr options:NSNumericSearch | NSCaseInsensitiveSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch range:NSMakeRange(0, objAttr.length) locale:[NSLocale currentLocale]];
            return result;
        };
    }
    else if (self.childrenSortedBy == FileSystemNodeSortedByDateLastOpened) {
        return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
            NSDate *objAttr = [obj1 lastUsedDate];
            NSDate *obj2Attr = [obj2 lastUsedDate];
            return [obj2Attr compare:objAttr];
        };
    }
    else if (self.childrenSortedBy == FileSystemNodeSortedByDateAdded) {
        return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
            NSDate *objAttr = [obj1 addedDate];
            NSDate *obj2Attr = [obj2 addedDate];
            return [obj2Attr compare:objAttr];
        };
    }
    else if (self.childrenSortedBy == FileSystemNodeSortedByDateModified) {
        return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
            NSDate *objAttr = [obj1 modificationDate];
            NSDate *obj2Attr = [obj2 modificationDate];
            return [obj2Attr compare:objAttr];
        };
    }
    else if (self.childrenSortedBy == FileSystemNodeSortedByDateCreated) {
        return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
            NSDate *objAttr = [obj1 creationDate];
            NSDate *obj2Attr = [obj2 creationDate];
            return [obj2Attr compare:objAttr];
        };
    }
    else if (self.childrenSortedBy == FileSystemNodeSortedBySize) {
        return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
            NSNumber *objAttr = @([obj1 size]);
            NSNumber *obj2Attr = @([obj2 size]);
            return [obj2Attr compare:objAttr];
        };
    }
    return ^NSComparisonResult(FileSystemNode *obj1, FileSystemNode *obj2) {
        NSString *objAttr = [obj1 displayName];
        NSString *obj2Attr = [obj2 displayName];
        NSComparisonResult result = [objAttr compare:obj2Attr options:NSNumericSearch | NSCaseInsensitiveSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch range:NSMakeRange(0, objAttr.length) locale:[NSLocale currentLocale]];
        return result;
    };
}

- (void)setChildrenSortedBy:(FileSystemNodeSortedBy)childrenSortedBy {
    _childrenSortedBy = childrenSortedBy;
    for (FileSystemNode *child in self.internalChildren) {
        [child setChildrenSortedBy:childrenSortedBy];
    }
}

- (void)invalidateChildren {
    _childrenDirty = YES;
    for (FileSystemNode *child in self.internalChildren) {
        [child invalidateChildren];
    }
}

@end
