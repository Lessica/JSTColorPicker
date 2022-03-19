// Copyright (c) 2013, Héctor Marqués
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
// REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
// AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
// INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
// LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
// OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

#import <CoreData/CoreData.h>

@class MRManagedObjectContext;


/**
 Simple Core Data Stack implementation.
 */
@interface MRSimpleCoreDataStack : NSObject {
    MRManagedObjectContext *_readOnlyContext;
    NSManagedObjectModel *_managedObjectModel;
    NSPersistentStoreCoordinator *_persistentStoreCoordinator;
}

/// Retrieves the shared instance of the stack.
+ (MRSimpleCoreDataStack *)sharedStack;

/// Frees the sharedStack.
+ (void)freeSharedStack;

@property (strong, nonatomic) NSString *persistentStoreFilename;
@property (strong, nonatomic) NSString *modelName;

/// Returns the managed object model.
/// If the model doesn't already exist, it is created from the application's model.
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;

/// Returns the persistent store coordinator.
/// If the coordinator doesn't already exist, it is created and the application's store added to it.
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

/// Returns the main managed object context.
/// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
@property (readonly, strong, nonatomic) NSManagedObjectContext *readOnlyContext;

/// You MUST enclose any modification in a managed object within this method's block or `performSync:` one.
- (void)performAsync:(void(^)(NSManagedObjectContext *readWriteContext))block;
/// You MUST enclose any modification in a managed object within this method's block or `performAsync:` one.
- (void)performSync:(void(^)(NSManagedObjectContext *readWriteContext))block;

/// Saves the main managed object changes.
/// You MUST use this method for saving the changes made pushed to read-only context when saving the read-write contexts.
- (BOOL)persistChanges:(NSError **)errorPtr;

@end
