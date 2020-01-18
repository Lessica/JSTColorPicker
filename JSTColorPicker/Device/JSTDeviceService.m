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
    [service.delegate deviceService:service handleiDeviceEvent:event];
}

@implementation JSTDeviceService

- (instancetype)init {
    self = [super init];
    if (self) {
        idevice_error_t error = idevice_event_subscribe(&handle_idevice_event, (__bridge void *)self);
        NSAssert(error == IDEVICE_E_SUCCESS, @"idevice_event_subscribe %d", error);
    }
    return self;
}

- (void)dealloc {
    idevice_event_unsubscribe();
}

- (NSArray <JSTDevice *> *)devices {
    char **cUDIDs;
    int cUDIDCount = 0;
    idevice_error_t error = idevice_get_device_list(&cUDIDs, &cUDIDCount);
    if (error != IDEVICE_E_SUCCESS) {
        return nil;
    }
    NSMutableArray <JSTDevice *> *newDevices = [NSMutableArray array];
    for (NSInteger i = 0; i < cUDIDCount; i++) {
        NSString *udid = [NSString stringWithUTF8String:cUDIDs[i]];
        JSTDevice *device = [[JSTDevice alloc] initWithUDID:udid];
        [newDevices addObject:device];
    }
    idevice_device_list_free(cUDIDs);
    return [newDevices copy];
}

@end
