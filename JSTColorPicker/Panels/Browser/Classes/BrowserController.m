/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Application Controller object, and the NSBrowser delegate. An instance of this object is in the MainMenu.xib.
 */

#import "BrowserController.h"
#import "FileSystemBrowserCell.h"
#import "PreviewViewController.h"
#import <AppKit/NSShadow.h>
#import <AppKit/NSAlert.h>
#import <AppKit/NSAttributedString.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSDocumentController.h>


@interface BrowserController ()

// please note bug #24527817
// NSBrowser column titles draw sporadic when navigating back with left arrow key (10.11)
//
@property (nonatomic, weak) IBOutlet NSBrowser *browser;

@property (nonatomic, strong) FileSystemNode *rootNode;
@property (nonatomic, assign) NSInteger draggedColumnIndex;

@property (nonatomic, strong) PreviewViewController *sharedPreviewController;
@property (nonatomic, strong) NSWindow *window;

@end


#pragma mark -

@implementation BrowserController

- (void)awakeFromNib {
    // use a custom cell class for each browser item
    [self.browser setCellClass:[FileSystemBrowserCell class]];
    
    // Drag and drop support
    [self.browser registerForDraggedTypes:@[NSFilenamesPboardType]];
    [self.browser setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [self.browser setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    
    // if you want to change the background color of NSBrowser use this:
    self.browser.titled = YES;
    self.browser.backgroundColor = [NSColor clearColor];
    self.browser.columnResizingType = NSBrowserAutoColumnResizing;
     
    // Double click support
    self.browser.target = self;
    self.browser.doubleAction = @selector(browserDoubleClick:);
}

- (id)rootItemForBrowser:(NSBrowser *)browser {
    if (self.rootNode == nil) {
        _rootNode = [[FileSystemNode alloc] initWithURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
    }
    return self.rootNode;
}

- (NSWindow *)window {
    return self.browser.window;
}

- (FileSystemNodeSortedBy)sortedBy {
    return self.rootNode.childrenSortedBy;
}


#pragma mark - Path Finder


#pragma mark - NSBrowserDelegate

// Required delegate methods
- (NSInteger)browser:(NSBrowser *)browser numberOfChildrenOfItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return node.children.count;
}

- (id)browser:(NSBrowser *)browser child:(NSInteger)index ofItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return (node.children)[index];
}

- (BOOL)browser:(NSBrowser *)browser isLeafItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return node.isLeafItem; // take into account packaged apps and documents
}

- (id)browser:(NSBrowser *)browser objectValueForItem:(id)item {
    FileSystemNode *node = (FileSystemNode *)item;
    return node.displayName;
}

- (void)browser:(NSBrowser *)browser willDisplayCell:(FileSystemBrowserCell *)cell atRow:(NSInteger)row column:(NSInteger)column {
    // Find the item and set the image.
    NSIndexPath *indexPath = [browser indexPathForColumn:column];
    indexPath = [indexPath indexPathByAddingIndex:row];
    FileSystemNode *node = [browser itemAtIndexPath:indexPath];
    cell.image = node.icon;
    cell.labelColor = node.labelColor;
}

- (NSViewController *)browser:(NSBrowser *)browser previewViewControllerForLeafItem:(id)item {
    if (!self.isLeafItemPreviewable || browser.numberOfVisibleColumns <= 1) {
        return nil;
    }
    if (self.sharedPreviewController == nil) {
        _sharedPreviewController = [[PreviewViewController alloc] initWithNibName:@"BrowserPreviewView" bundle:[NSBundle bundleForClass:[self class]]];
    }
    return self.sharedPreviewController; // NSBrowser will set the representedObject for us
}

- (NSViewController *)browser:(NSBrowser *)browser headerViewControllerForItem:(id)item {
    // Add a header for the first column, just as an example
    if (self.rootNode == item) {
        return [[NSViewController alloc] initWithNibName:@"BrowserHeaderView" bundle:[NSBundle bundleForClass:[self class]]];
    } else {
        return nil;
    }
}

- (CGFloat)browser:(NSBrowser *)browser shouldSizeColumn:(NSInteger)columnIndex forUserResize:(BOOL)forUserResize toWidth:(CGFloat)suggestedWidth  {
    if (!forUserResize) {
        id item = [browser parentForItemsInColumn:columnIndex]; 
        if ([self browser:browser isLeafItem:item]) {
            suggestedWidth = 200; 
        }
    }
    return suggestedWidth;
}


#pragma mark - Dragging Source

- (BOOL)browser:(NSBrowser *)browser writeRowsWithIndexes:(NSIndexSet *)rowIndexes inColumn:(NSInteger)column toPasteboard:(NSPasteboard *)pasteboard {
    NSMutableArray *filenames = [NSMutableArray arrayWithCapacity:rowIndexes.count];
    NSIndexPath *baseIndexPath = [browser indexPathForColumn:column]; 
    for (NSUInteger i = rowIndexes.firstIndex; i <= rowIndexes.lastIndex; i = [rowIndexes indexGreaterThanIndex:i]) {
        FileSystemNode *fileSystemNode = [browser itemAtIndexPath:[baseIndexPath indexPathByAddingIndex:i]]; 
        [filenames addObject:(fileSystemNode.URL).path];
    }
    [pasteboard declareTypes:@[NSFilenamesPboardType] owner:self];
    [pasteboard setPropertyList:filenames forType:NSFilenamesPboardType];
    _draggedColumnIndex = column;
    return YES;
}

- (BOOL)browser:(NSBrowser *)browser canDragRowsWithIndexes:(NSIndexSet *)rowIndexes inColumn:(NSInteger)column withEvent:(NSEvent *)event {
    // We will allow dragging any cell - even disabled ones. By default, NSBrowser will not let you drag a disabled cell
    return YES;
}

- (NSImage *)browser:(NSBrowser *)browser draggingImageForRowsWithIndexes:(NSIndexSet *)rowIndexes inColumn:(NSInteger)column withEvent:(NSEvent *)event offset:(NSPointPointer)dragImageOffset {
    NSImage *result = [browser draggingImageForRowsWithIndexes:rowIndexes inColumn:column withEvent:event offset:dragImageOffset];
    
    // Create a custom drag image "badge" that displays the number of items being dragged
    if (rowIndexes.count > 1) {
        NSString *str = [NSString stringWithFormat:NSLocalizedString(@"%ld items being dragged", @"Browser"), (long)rowIndexes.count];
        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowOffset = NSMakeSize(0.5, 0.5);
        shadow.shadowBlurRadius = 5.0;
        shadow.shadowColor = [NSColor blackColor];
        
        NSDictionary *attrs = @{NSShadowAttributeName: shadow, 
                               NSForegroundColorAttributeName: [NSColor whiteColor]};
        
        NSAttributedString *countString = [[NSAttributedString alloc] initWithString:str attributes:attrs];
        NSSize stringSize = [countString size];
        NSSize imageSize = result.size;
        imageSize.height += stringSize.height;
        imageSize.width = MAX(stringSize.width + 3, imageSize.width);
        
        NSImage *newResult = [[NSImage alloc] initWithSize:imageSize];
        
        [newResult lockFocus];
    
        [result drawAtPoint:NSMakePoint(0, 0) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        [countString drawAtPoint:NSMakePoint(0, imageSize.height - stringSize.height)];
        [newResult unlockFocus];
        
        
        dragImageOffset->y += (stringSize.height / 2.0);
        result = newResult;
    }
    return result;
}


#pragma mark - Dragging Destination

- (FileSystemNode *)fileSystemNodeAtRow:(NSInteger)row column:(NSInteger)column {
    if (column >= 0) {
        NSIndexPath *indexPath = [self.browser indexPathForColumn:column];
        if (row >= 0) {
            indexPath = [indexPath indexPathByAddingIndex:row];
        }
        id result = [self.browser itemAtIndexPath:indexPath];
        return (FileSystemNode *)result;
    } else {
        return nil;
    }
}

- (NSDragOperation)browser:(NSBrowser *)browser validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger *)row column:(NSInteger *)column  dropOperation:(NSBrowserDropOperation *)dropOperation {
    NSDragOperation result = NSDragOperationNone;
    
    // We only accept file types
    if ([[info draggingPasteboard].types indexOfObject:NSFilenamesPboardType] > 0) {
        // For a between drop, we let the user drop "on" the parent item
        if (*dropOperation == NSBrowserDropAbove) {
            *row = -1;
        }
        // Only allow dropping in folders, but don't allow dragging from the same folder into itself, if we are the source
        if (*column != -1) {
            BOOL droppingFromSameFolder = ([info draggingSource] == browser) && (*column == self.draggedColumnIndex);
            if (*row != -1) {
                // If we are dropping on a folder, then we will accept the drop at that row
                FileSystemNode *toFileSystemNode = [self fileSystemNodeAtRow:*row column:*column];
                if (!toFileSystemNode.isLeafItem) {
                    NSArray <NSString *> *filenames = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
                    if ([filenames count] == 1 && [[NSURL fileURLWithPath:filenames.firstObject] isEqual:toFileSystemNode.URL]) {
                        result = NSDragOperationNone;
                    }
                    else if ([filenames count] != 0 && [[[NSURL fileURLWithPath:filenames.firstObject] URLByDeletingLastPathComponent] isEqual:toFileSystemNode.URL]) {
                        result = NSDragOperationNone;
                    }
                    else {
                        // Yup, a good drop
                        result = NSDragOperationEvery;
                    }
                } else {
                    // Nope, we can't drop onto a file! We will retarget to the column, if it isn't the same folder.
                    if (!droppingFromSameFolder) {
                        result = NSDragOperationEvery;
                        *row = -1;
                        *dropOperation = NSBrowserDropOn;
                    }
                }
            } else if (!droppingFromSameFolder) {
                result = NSDragOperationEvery;
                *row = -1;
                *dropOperation = NSBrowserDropOn;
            }
        }
    }
    return result;
}

- (void)browser:(NSBrowser *)browser didChangeLastColumn:(NSInteger)oldLastColumn toColumn:(NSInteger)column {
    if ([self.delegate respondsToSelector:@selector(browserControllerDidChangeColumn:)]) {
        [self.delegate browserControllerDidChangeColumn:self];
    }
}

- (BOOL)browser:(NSBrowser *)browser acceptDrop:(id <NSDraggingInfo>)info atRow:(NSInteger)row column:(NSInteger)column dropOperation:(NSBrowserDropOperation)dropOperation {
    NSArray <NSString *> *filenames = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    // Find the target folder
    FileSystemNode *targetFileSystemNode = nil;
    if ((column != -1) && (filenames != nil)) {
        if (row != -1) {
            FileSystemNode *fileSystemNode = [self fileSystemNodeAtRow:row column:column];
            if (!fileSystemNode.isLeafItem) {
                targetFileSystemNode = fileSystemNode;
            }
        } else {
            // Grab the parent for the column, which should be a directory
            targetFileSystemNode = (FileSystemNode *)[browser parentForItemsInColumn:column];
        }
    }
    
    // We now have the target folder, so move things around    
    if (targetFileSystemNode != nil) {
        NSString *targetFolder = targetFileSystemNode.URL.path;
        
        NSMutableString *prettyNames = nil;

        // Create a display name of all the selected filenames that are moving
        for (NSUInteger i = 0; i < filenames.count; i++) {
            NSString *filename = [[NSFileManager defaultManager] displayNameAtPath:filenames[i]];
            if (prettyNames == nil) {
                prettyNames = [filename mutableCopy];                
            } else {
                [prettyNames appendString:@", "];
                [prettyNames appendString:filename];
            }
        }
        
        // Ask the user if they really want to move those files
        NSAlert *warningAlert = [[NSAlert alloc] init];
        warningAlert.messageText = NSLocalizedString(@"Confirm file move", @"Browser");
        warningAlert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to move '%@' to '%@'?", @"Browser"), prettyNames, targetFolder];
        [warningAlert addButtonWithTitle:NSLocalizedString(@"Yes", @"Browser")];
        [warningAlert addButtonWithTitle:NSLocalizedString(@"No", @"Browser")];
        [warningAlert beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            if (result == NSAlertFirstButtonReturn) {
                // Do the actual moving of the files.
                for (NSUInteger i = 0; i < filenames.count; i++) {
                    NSString *filename = filenames[i];
                    NSString *targetPath = [targetFolder stringByAppendingPathComponent:filename.lastPathComponent];
                    
                    // Normally, you should check the result of movePath to see if it worked or not.
                    NSError *error = nil;
                    if (![[NSFileManager defaultManager] moveItemAtPath:filename toPath:targetPath error:&error] && error) {
                        [self.browser presentError:error];
                        break;
                    }
                }
                
                // It would be more efficient to invalidate the children of the "from" and "to" nodes and then
                // call -reloadColumn: on each of the corresponding columns. However, we just reload every column
                //
                [self.rootNode invalidateChildren];
                for (NSInteger col = self.browser.lastColumn; col >= 0; col--) {
                    [self.browser reloadColumn:col];
                }
            }
        }];
        return YES;
    }
    return NO;
}


#pragma mark - Action

- (void)browserDoubleClick:(id)sender {
    // Find the clicked item and open it in Finder
    FileSystemNode *clickedNode = [self fileSystemNodeAtRow:self.browser.clickedRow column:self.browser.clickedColumn];
    if (clickedNode != nil) {
        [self openNode:clickedNode];
    }
}

- (BOOL)openNode:(FileSystemNode *)clickedNode {
    BOOL opened = [self openInternalNode:clickedNode];
    if (!opened) {
        opened = [self openExternalNode:clickedNode];
    }
    return opened;
}

- (BOOL)openInternalNode:(FileSystemNode *)clickedNode {
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
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:clickedNode.URL display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kJSTColorPickerNotificationNameDropRespondingWindowChanged object:nil];
            if (error) {
                [self.browser presentError:error];
            }
        }];
    }
    return handleBySelf;
}

- (BOOL)openExternalNode:(FileSystemNode *)clickedNode {
    return [[NSWorkspace sharedWorkspace] openURL:clickedNode.URL];
}

- (void)invalidate {
    [self.rootNode invalidateChildren];
}

@end
