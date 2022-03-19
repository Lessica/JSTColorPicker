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

#import "MRManagedObjectContext.h"


@implementation NSManagedObjectContext (MRManagedObjectContext)

- (BOOL)isReadOnlyContext
{
    return NO;
}

@end


@implementation MRManagedObjectContext

- (BOOL)save:(NSError **const)errorPtr
{
    BOOL saved;
    if (_failsOnSave) {
        if (errorPtr) {
            NSDictionary *const userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"Unable to write a read-only context.", nil) };
            *errorPtr = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSPersistentStoreSaveError
                                        userInfo:userInfo];
        }
        if (_throwsExceptionOnSave) {
            [NSException raise:NSGenericException format:@"Unsupported operation"];
        }
        saved = NO;
    } else {
        if (_throwsExceptionOnSave) {
            [NSException raise:NSGenericException format:@"Unsupported operation"];
        } else {
            saved = [super save:errorPtr];
        }
    }
    return saved;
}

- (BOOL)save:(NSError *__autoreleasing *const)errorPtr forced:(BOOL const)forced
{
    BOOL saved;
    if (forced) {
        saved = [super save:errorPtr];
    } else {
        saved = [self save:errorPtr];
    }
    return saved;
}

#pragma mark - NSManagedObjectContext (MRManagedObjectContext)

- (BOOL)isReadOnlyContext
{
    return _throwsExceptionOnSave || _failsOnSave;
}

@end
