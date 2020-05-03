//
//  JSTConnectedDeviceStore.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTConnectedDeviceStore.h"
#import "JSTConnectedDevice.h"
#import <libimobiledevice/lockdown.h>

static void handle_idevice_event(const idevice_event_t *event, void *user_data) {
    JSTConnectedDeviceStore *service = (__bridge JSTConnectedDeviceStore *)(user_data);
    [service.delegate didReceiveiDeviceEvent:service];
}

@implementation JSTConnectedDeviceStore

- (instancetype)init {
    self = [super init];
    if (self) {
        idevice_error_t error = idevice_event_subscribe(&handle_idevice_event, (__bridge void *)self);
        NSAssert(error == IDEVICE_E_SUCCESS, @"idevice_event_subscribe %d", error);
        _activeDevices = [NSMutableDictionary dictionary];
        _cachedDevices = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    idevice_event_unsubscribe();
}

- (NSArray <JSTConnectedDevice *> *)connectedDevicesIncludingNetworkDevices:(BOOL)includingNetworkDevices {
    if (includingNetworkDevices) {
        idevice_info_t *cDevices;
        int cUDIDCount = 0;
        idevice_error_t error = idevice_get_device_list_extended(&cDevices, &cUDIDCount);
        if (error != IDEVICE_E_SUCCESS) {
            return nil;
        }
        [self.activeDevices removeAllObjects];
        for (NSInteger i = 0; i < cUDIDCount; i++) {
            NSString *udid = [NSString stringWithUTF8String:cDevices[i]->udid];
            if (self.cachedDevices[udid]) {
                if (self.activeDevices[udid]) {
                    continue;
                }
                else {
                    self.activeDevices[udid] = self.cachedDevices[udid];
                }
            }
            else {
                JSTConnectedDevice *device = [[JSTConnectedDevice alloc] initWithUDID:udid];
                self.cachedDevices[udid] = device;
                self.activeDevices[udid] = device;
            }
        }
        
        idevice_device_list_extended_free(cDevices);
        return [self.activeDevices allValues];
    }
    else {
        char **cUDIDs;
        int cUDIDCount = 0;
        idevice_error_t error = idevice_get_device_list(&cUDIDs, &cUDIDCount);
        if (error != IDEVICE_E_SUCCESS) {
            return nil;
        }
        [self.activeDevices removeAllObjects];
        for (NSInteger i = 0; i < cUDIDCount; i++) {
            NSString *udid = [NSString stringWithUTF8String:cUDIDs[i]];
            if (self.cachedDevices[udid]) {
                if (self.activeDevices[udid]) {
                    continue;
                }
                else {
                    self.activeDevices[udid] = self.cachedDevices[udid];
                }
            }
            else {
                JSTConnectedDevice *device = [[JSTConnectedDevice alloc] initWithUDID:udid];
                self.cachedDevices[udid] = device;
                self.activeDevices[udid] = device;
            }
        }
        
        idevice_device_list_free(cUDIDs);
        return [self.activeDevices allValues];
    }
}

- (void)disconnectDevice:(JSTConnectedDevice *)device {
    [self.activeDevices removeObjectForKey:device.udid];
    [self.cachedDevices removeObjectForKey:device.udid];
}

- (void)disconnectAllDevices {
    [self.activeDevices removeAllObjects];
    [self.cachedDevices removeAllObjects];
}

@end