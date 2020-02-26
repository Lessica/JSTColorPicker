//
//  JSTDeviceService.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTDeviceService.h"
#import "JSTDevice.h"
#import <libimobiledevice/lockdown.h>

static void handle_idevice_event(const idevice_event_t *event, void *user_data) {
    JSTDeviceService *service = (__bridge JSTDeviceService *)(user_data);
    [service.delegate didReceiveiDeviceEvent:service];
}

@interface JSTDeviceService ()
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTDevice *> *activeDevices;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTDevice *> *allDevices;
@end

@implementation JSTDeviceService

- (instancetype)init {
    self = [super init];
    if (self) {
        idevice_error_t error = idevice_event_subscribe(&handle_idevice_event, (__bridge void *)self);
        NSAssert(error == IDEVICE_E_SUCCESS, @"idevice_event_subscribe %d", error);
        _activeDevices = [NSMutableDictionary dictionary];
        _allDevices = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    idevice_event_unsubscribe();
}

- (NSArray <JSTDevice *> *)devicesIncludingNetworkDevices:(BOOL)includingNetworkDevices {
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
            if (self.allDevices[udid]) {
                if (self.activeDevices[udid]) {
                    continue;
                }
                else {
                    self.activeDevices[udid] = self.allDevices[udid];
                }
            }
            else {
                JSTDevice *device = [[JSTDevice alloc] initWithUDID:udid];
                self.allDevices[udid] = device;
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
            if (self.allDevices[udid]) {
                if (self.activeDevices[udid]) {
                    continue;
                }
                else {
                    self.activeDevices[udid] = self.allDevices[udid];
                }
            }
            else {
                JSTDevice *device = [[JSTDevice alloc] initWithUDID:udid];
                self.allDevices[udid] = device;
                self.activeDevices[udid] = device;
            }
        }
        
        idevice_device_list_free(cUDIDs);
        return [self.activeDevices allValues];
    }
}

@end
