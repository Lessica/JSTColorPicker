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

#import "MRSimpleCoreDataStack.h"

#import "MRManagedObjectContext.h"


static dispatch_once_t __onceToken = 0L;


@interface MRSimpleCoreDataStack ()
@end


@implementation MRSimpleCoreDataStack

+ (MRSimpleCoreDataStack *)sharedStack
{
    static MRSimpleCoreDataStack *instance = nil;
    dispatch_once(&__onceToken, ^{
        instance = [[MRSimpleCoreDataStack alloc] init];
    });
    return instance;
}

+ (void)freeSharedStack
{
    __onceToken = 0L;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSString *const modelName = self.modelName;
    NSURL *const modelURL = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSAssert(_managedObjectModel, @"Model cannot be nil");
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSString *const filename = self.persistentStoreFilename;
    NSURL *const storeURL = [self.mr_applicationDocumentsDirectory URLByAppendingPathComponent:filename];

    NSError *error = nil;
    NSPersistentStoreCoordinator *const persistentStoreCoordinator =
    [self persistentStoreCoordinatorWithStoreURL:storeURL withRecoveredError:&error];
    NSAssert(error == nil, @"Unhandled error");
    return persistentStoreCoordinator;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinatorWithStoreURL:(NSURL *)storeURL withRecoveredError:(NSError **const)errorPtr
{
    NSDictionary *const options =  @{ NSMigratePersistentStoresAutomaticallyOption: @YES,
                                      NSInferMappingModelAutomaticallyOption: @YES };
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        NSFileManager *const fileManager = NSFileManager.defaultManager;
        NSString *const path = storeURL.path;
        NSError *deleteError = nil;
        if (errorPtr) {
            *errorPtr = error;
            if ([fileManager fileExistsAtPath:path] == NO) {
                NSAssert(error == nil, @"Unhandled error");
                return nil;
            } else {
                NSString *const extension = [NSString stringWithFormat:@"%lu.bkp", (long int)NSDate.timeIntervalSinceReferenceDate];
                NSString *const copyPath = [path stringByAppendingPathExtension:extension];
                NSError *copyError = nil;
                if ([fileManager copyItemAtPath:path toPath:copyPath error:&copyError] == NO) {
                    NSAssert(error == nil, @"Unhandled error");
                }
            }
            if ([fileManager removeItemAtPath:path error:&deleteError] == NO) {
                NSAssert(error == nil, @"Unhandled error");
                NSString *const extension = [NSString stringWithFormat:@"%lu.tmp", (long int)NSDate.timeIntervalSinceReferenceDate];
                storeURL = [storeURL URLByAppendingPathExtension:extension];
                NSAssert(error == nil, @"Unhandled error");
            }
            return [self persistentStoreCoordinatorWithStoreURL:storeURL withRecoveredError:NULL];
        } else {
            NSAssert(error == nil, @"Unhandled error");
            abort();
        }
    }
    
    return _persistentStoreCoordinator;
}

- (void)performAsync:(void (^const)(NSManagedObjectContext *moc))block
{
    NSManagedObjectContext *const moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = self.readOnlyContext;
    [moc performBlock:^{
        block(moc);
    }];
}

- (void)performSync:(void (^const)(NSManagedObjectContext *moc))block
{
    NSManagedObjectContext *const moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = self.readOnlyContext;
    [moc performBlockAndWait:^{
        block(moc);
    }];
}

- (NSManagedObjectContext *)readOnlyContext
{
    if (_readOnlyContext == nil) {
        @synchronized(self) {
            if (_readOnlyContext == nil) {
                NSPersistentStoreCoordinator *const coordinator = [self persistentStoreCoordinator];
                if (coordinator != nil) {
                    _readOnlyContext = [[MRManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                    _readOnlyContext.failsOnSave = YES;
                    [_readOnlyContext setPersistentStoreCoordinator:coordinator];
                    [_readOnlyContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
                }
            }
        }
    }
    return _readOnlyContext;
}

- (BOOL)persistChanges:(NSError *__autoreleasing *const)errorPtr
{
    __block BOOL saved;
    if (_readOnlyContext.hasChanges) {
        if (NSThread.isMainThread) {
            saved = [_readOnlyContext save:errorPtr forced:YES];
        } else {
            [_readOnlyContext performBlockAndWait:^{
                saved = [_readOnlyContext save:errorPtr forced:YES];
            }];
        }
    } else {
        saved = NO;
    }
    return saved;
}

#pragma mark Accessors

- (NSString *)persistentStoreFilename
{
    if (_persistentStoreFilename == nil) {
        @synchronized(self) {
            if (_persistentStoreFilename == nil) {
                NSString *const applicationName = [NSBundle.mainBundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleNameKey];
                _persistentStoreFilename =
                [NSString stringWithFormat:@"%@.sqlite", applicationName];
            }
        }
    }
    return _persistentStoreFilename;
}

- (NSString *)modelName
{
    if (_modelName == nil) {
        @synchronized(self) {
            if (_modelName == nil) {
                _modelName = [NSBundle.mainBundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleNameKey];;
            }
        }
    }
    return _modelName;
}

#pragma mark Private

- (NSURL *)mr_applicationDocumentsDirectory
{
    NSFileManager *const defaultManager = NSFileManager.defaultManager;
    NSArray *const urls =
    [defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *const lastObject = urls.lastObject;
    return lastObject;
}

@end
