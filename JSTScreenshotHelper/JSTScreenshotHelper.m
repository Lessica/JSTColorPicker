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
@end

@implementation JSTScreenshotHelper

- (void)setNetworkDiscoveryEnabled:(BOOL)enabled {
    _isNetworkDiscoveryEnabled = enabled;
}

- (void)discoveredDevicesWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    NSMutableArray <NSDictionary *> *discoveredDevices = [[NSMutableArray alloc] initWithCapacity:self.deviceService.activeDevices.count];
    for (JSTConnectedDevice *connectedDevice in self.deviceService.activeDevices.allValues) {
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
    JSTConnectedDevice *targetDevice = self.deviceService.cachedDevices[udid];
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
    JSTConnectedDevice *targetDevice = self.deviceService.cachedDevices[udid];
    if (!targetDevice) {
        targetDevice = [JSTConnectedDevice deviceWithUDID:udid];
    }
    if (!targetDevice) {
        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Device \"%@\" is not reachable.", @"kJSTScreenshotError"), udid] }]);
        return;
    }
    __weak typeof(self) weakSelf = self;
    [targetDevice takeScreenshotWithCompletionHandler:^(NSData * _Nullable imageData, NSError * _Nullable error) {
        reply(imageData, error);
        if (error) {
            [weakSelf disconnectDevice:targetDevice];
            [weakSelf didReceiveiDeviceEvent:self.deviceService];
        }
    }];
}

- (void)disconnectDevice:(JSTConnectedDevice *)device {
    [self.deviceService disconnectDevice:device];
}

- (void)disconnectAllDevices {
    [self.deviceService disconnectAllDevices];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray <JSTConnectedDevice *> *connectedDevices = [service connectedDevicesIncludingNetworkDevices:self.isNetworkDiscoveryEnabled];
        NSLog(@"%@", connectedDevices);
    });
}

@end
