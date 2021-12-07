/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 An abstract wrapper node around the file system.
 */

#import "FileSystemNode.h"

@interface FileSystemNode ()

@property (strong) NSURL *URL;
@property (assign) BOOL childrenDirty;
@property (strong) NSArray *internalChildren;

@end


#pragma mark -

@implementation FileSystemNode

@dynamic displayName, children, isDirectory, icon, labelColor, documentKind, size, formattedFileSize, creationDate, modificationDate, lastUsedDate;

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
    return [[NSWorkspace sharedWorkspace] iconForFile:(self.URL).path];
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
        
        CFURLEnumeratorRef enumerator = CFURLEnumeratorCreateForDirectoryURL(NULL, (CFURLRef)self.URL, kCFURLEnumeratorSkipInvisibles, (CFArrayRef)[NSArray array]);
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
        _internalChildren = [newChildren sortedArrayUsingComparator:^(id obj1, id obj2) {
            NSString *objName = [obj1 displayName];
            NSString *obj2Name = [obj2 displayName];
            NSComparisonResult result = [objName compare:obj2Name options:NSNumericSearch | NSCaseInsensitiveSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch range:NSMakeRange(0, objName.length) locale:[NSLocale currentLocale]];
            return result;
        }];
    }
    
    return self.internalChildren;
}

- (void)invalidateChildren {
    _childrenDirty = YES;
    for (FileSystemNode *child in self.internalChildren) {
        [child invalidateChildren];
    }
}

@end
