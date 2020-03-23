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
@property (nonatomic, assign) BOOL includingNetworkDevices;
@property (nonatomic, strong) NSArray <JSTConnectedDevice *> *connectedDevices;
@property (nonatomic, strong) JSTConnectedDeviceStore *deviceService;
@end

@implementation JSTScreenshotHelper

- (void)setIncludingNetworkDevices:(BOOL)includingNetworkDevices {
    _includingNetworkDevices = includingNetworkDevices;
}

- (NSArray <JSTXPCDevice *> *)discoveredDevices {
    NSMutableArray <JSTXPCDevice *> *discoveredDevices = [[NSMutableArray alloc] initWithCapacity:self.connectedDevices.count];
    for (JSTConnectedDevice *connectedDevice in self.connectedDevices) {
        JSTXPCDevice *discoveredDevice = [[JSTXPCDevice alloc] initWithUDID:connectedDevice.udid andName:connectedDevice.name];
        [discoveredDevices addObject:discoveredDevice];
    }
    return discoveredDevices;
}


- (void)takeScreenshot:(JSTXPCDevice *)aDevice withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    JSTConnectedDevice *targetDevice = nil;
    for (JSTConnectedDevice *device in self.connectedDevices) {
        if ([device.udid isEqualToString:aDevice.udid]) {
            targetDevice = device;
            break;
        }
    }
    if (!targetDevice) {
        targetDevice = [JSTConnectedDevice deviceWithUDID:aDevice.udid];
    }
    if (!targetDevice) {
        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Device \"%@\" is not reachable.", @"kJSTScreenshotError"), aDevice.name] }]);
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
    }
    return self;
}

- (void)didReceiveiDeviceEvent:(nonnull JSTConnectedDeviceStore *)service {
    _connectedDevices = [service connectedDevicesIncludingNetworkDevices:self.includingNetworkDevices];
}

@end
