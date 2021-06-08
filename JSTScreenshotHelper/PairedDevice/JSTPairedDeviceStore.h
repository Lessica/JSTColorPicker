//
//  JSTPairedDeviceStore.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libimobiledevice/libimobiledevice.h>

NS_ASSUME_NONNULL_BEGIN

@class JSTPairedDeviceStore, JSTPairedDevice;

@protocol JSTPairedDeviceDelegate <NSObject>
- (void)didReceiveiDeviceEvent:(JSTPairedDeviceStore *)service;
@end

@interface JSTPairedDeviceStore : NSObject

@property (nonatomic, weak) id <JSTPairedDeviceDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTPairedDevice *> *activeDevices;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTPairedDevice *> *cachedDevices;

- (void)disconnectDevice:(JSTPairedDevice *)device;
- (void)disconnectAllDevices;
- (NSArray <JSTPairedDevice *> *)connectedDevicesIncludingNetworkDevices:(BOOL)includingNetworkDevices;

@end

NS_ASSUME_NONNULL_END
