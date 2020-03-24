//
//  JSTScreenshotHelper.m
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTScreenshotHelper.h"
#import "JSTConnectedDevice.h"
#import "JSTConnectedDeviceStore.h"

@interface JSTScreenshotHelper () <JSTDeviceDelegate>
@property (nonatomic, assign) BOOL isNetworkDiscoveryEnabled;
@property (nonatomic, strong) NSArray <JSTConnectedDevice *> *connectedDevices;
@property (nonatomic, strong) JSTConnectedDeviceStore *deviceService;
@end

@implementation JSTScreenshotHelper

- (void)setNetworkDiscoveryEnabled:(BOOL)enabled {
    _isNetworkDiscoveryEnabled = enabled;
}

- (void)discoveredDevicesWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    NSMutableArray <NSDictionary *> *discoveredDevices = [[NSMutableArray alloc] initWithCapacity:self.connectedDevices.count];
    for (JSTConnectedDevice *connectedDevice in self.connectedDevices) {
        [discoveredDevices addObject:@{
            @"name": connectedDevice.name,
            @"udid": connectedDevice.udid,
        }];
    }
    reply([NSPropertyListSerialization dataWithPropertyList:discoveredDevices
                                                     format:NSPropertyListBinaryFormat_v1_0
                                                    options:0
                                                      error:nil], nil);
}

- (void)lookupDeviceByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    JSTConnectedDevice *targetDevice = nil;
    for (JSTConnectedDevice *connectedDevice in self.connectedDevices) {
        if ([connectedDevice.udid isEqualToString:udid]) {
            targetDevice = connectedDevice;
            break;
        }
    }
    if (!targetDevice) {
        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Device \"%@\" is not reachable.", @"kJSTScreenshotError"), udid] }]);
        return;
    }
    reply([NSPropertyListSerialization dataWithPropertyList:@{
        @"name": targetDevice.name,
        @"udid": targetDevice.udid,
    } format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil], nil);
}

- (void)takeScreenshotByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    JSTConnectedDevice *targetDevice = nil;
    for (JSTConnectedDevice *device in self.connectedDevices) {
        if ([device.udid isEqualToString:udid]) {
            targetDevice = device;
            break;
        }
    }
    if (!targetDevice) {
        targetDevice = [JSTConnectedDevice deviceWithUDID:udid];
    }
    if (!targetDevice) {
        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Device \"%@\" is not reachable.", @"kJSTScreenshotError"), udid] }]);
        return;
    }
    [targetDevice takeScreenshotWithCompletionHandler:^(NSData * _Nullable imageData, NSError * _Nullable error) {
        reply(imageData, error);
    }];
}

- (instancetype)init {
    self = [super init];
    if (self)
    {
        _deviceService = [[JSTConnectedDeviceStore alloc] init];
        _deviceService.delegate = self;
        [self didReceiveiDeviceEvent:self.deviceService];
    }
    return self;
}

- (void)didReceiveiDeviceEvent:(nonnull JSTConnectedDeviceStore *)service {
    _connectedDevices = [service connectedDevicesIncludingNetworkDevices:self.isNetworkDiscoveryEnabled];
    NSLog(@"%@", self.connectedDevices);
}

@end
