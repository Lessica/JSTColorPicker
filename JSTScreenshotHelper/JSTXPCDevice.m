//
//  JSTXPCDevice.m
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTXPCDevice.h"

@implementation JSTXPCDevice

- (instancetype)initWithUDID:(NSString *)udid andName:(NSString *)name {
    self = [super init];
    if (self) {
        _udid = udid;
        _name = name;
    }
    return self;
}

- (NSString *)menuTitle {
    return [NSString stringWithFormat:@"%@ (%@)", self.name, self.udid];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.udid forKey:@"udid"];
    [coder encodeObject:self.name forKey:@"name"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    NSString *udid = [coder decodeObjectForKey:@"udid"];
    if (!udid) return nil;
    NSString *name = [coder decodeObjectForKey:@"name"];
    if (!name) return nil;
    return [self initWithUDID:udid andName:name];
}

@end
