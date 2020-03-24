//
//  JSTConnectedDeviceStore.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libimobiledevice/libimobiledevice.h>

NS_ASSUME_NONNULL_BEGIN

@class JSTConnectedDeviceStore, JSTConnectedDevice;

@protocol JSTDeviceDelegate <NSObject>
- (void)didReceiveiDeviceEvent:(JSTConnectedDeviceStore *)service;
@end

@interface JSTConnectedDeviceStore : NSObject

@property (nonatomic, weak) id <JSTDeviceDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTConnectedDevice *> *activeDevices;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTConnectedDevice *> *cachedDevices;

- (void)disconnectDevice:(JSTConnectedDevice *)device;
- (void)disconnectAllDevices;
- (NSArray <JSTConnectedDevice *> *)connectedDevicesIncludingNetworkDevices:(BOOL)includingNetworkDevices;

@end

NS_ASSUME_NONNULL_END
