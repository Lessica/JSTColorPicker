//
//  JSTPairedDeviceStore.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTScreenshotHelperProtocol.h"
#import "JSTPairedDeviceStore.h"
#import "JSTPairedDevice.h"
#import <libimobiledevice/lockdown.h>

static void handle_idevice_event(const idevice_event_t *event, void *user_data) {
    JSTPairedDeviceStore *service = (__bridge JSTPairedDeviceStore *)(user_data);
    [service.delegate didReceiveiDeviceEvent:service];
}

@implementation JSTPairedDeviceStore

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

- (NSArray <JSTPairedDevice *> *)connectedDevicesIncludingNetworkDevices:(BOOL)includingNetworkDevices {
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
                JSTPairedDevice *device = self.cachedDevices[udid];
                if (cDevices[i]->conn_type == CONNECTION_USBMUXD) {
                    device.type = JSTDeviceTypeUSB;
                } else {
                    device.type = JSTDeviceTypeNetwork;
                }
                if (self.activeDevices[udid]) {
                    continue;
                } else {
                    self.activeDevices[udid] = device;
                }
            }
            else {
                NSString *deviceType = nil;
                if (cDevices[i]->conn_type == CONNECTION_USBMUXD) {
                    deviceType = JSTDeviceTypeUSB;
                } else {
                    deviceType = JSTDeviceTypeNetwork;
                }
                JSTPairedDevice *device = [[JSTPairedDevice alloc] initWithUDID:udid type:deviceType];
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
                JSTPairedDevice *device = self.cachedDevices[udid];
                device.type = JSTDeviceTypeUSB;
                if (self.activeDevices[udid]) {
                    continue;
                } else {
                    self.activeDevices[udid] = device;
                }
            }
            else {
                JSTPairedDevice *device = [[JSTPairedDevice alloc] initWithUDID:udid type:JSTDeviceTypeUSB];
                self.cachedDevices[udid] = device;
                self.activeDevices[udid] = device;
            }
        }
        
        idevice_device_list_free(cUDIDs);
        return [self.activeDevices allValues];
    }
}

- (void)disconnectDevice:(JSTPairedDevice *)device {
    [self.activeDevices removeObjectForKey:device.udid];
    [self.cachedDevices removeObjectForKey:device.udid];
}

- (void)disconnectAllDevices {
    [self.activeDevices removeAllObjects];
    [self.cachedDevices removeAllObjects];
}

@end
