//
//  JSTDevice.m
//  JSTColorPicker
//
//  Created by Darwin on 6/7/21.
//  Copyright © 2021 JST. All rights reserved.
//

#import "JSTDevice.h"

@implementation JSTDevice

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: [%@/%@/%@/%@/%@]>",
            NSStringFromClass([JSTDevice class]),
            [self.type uppercaseString],
            self.name,
            self.base,
            self.model,
            self.version];
}

- (BOOL)isEqual:(JSTDevice *)object {
    return [self.base isEqualToString:object.base];
}

- (instancetype)initWithBase:(NSString *)base
                        Name:(NSString *)name
                       Model:(NSString *)model
                        Type:(JSTDeviceType)type
                     Version:(NSString *)version
{
    if (self = [super init]) {
        _base = base;
        _name = name;
        _model = model;
        _type = type;
        _version = version;
        assert([self hasValidType]);
    }
    return self;
}

- (BOOL)hasValidType {
    return [[self type] isEqualToString:JSTDeviceTypeUSB] || [[self type] isEqualToString:JSTDeviceTypeNetwork] || [[self type] isEqualToString:JSTDeviceTypeBonjour];
}

- (void)setType:(JSTDeviceType)type {
    _type = type;
    assert([self hasValidType]);
}

- (void)takeScreenshotWithCompletionHandler:(JSTScreenshotHandler)completion {
    NSAssert(NO, @"Not implemented");
}

@end
