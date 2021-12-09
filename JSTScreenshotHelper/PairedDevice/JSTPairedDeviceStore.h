//
//  JSTPairedDeviceStore.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libimobiledevice/libimobiledevice.h>
#import "JSTPairedDevice.h"

NS_ASSUME_NONNULL_BEGIN

@class JSTPairedDeviceStore;

@protocol JSTPairedDeviceDelegate <NSObject>
- (void)didReceiveiDeviceEvent:(nullable JSTPairedDeviceStore *)service;
@end

@interface JSTPairedDeviceStore : NSObject

@property (nonatomic, weak) id <JSTPairedDeviceDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTDevice <JSTPairedDevice> *> *activeDevices;
@property (nonatomic, strong) NSMutableDictionary <NSString *, JSTDevice <JSTPairedDevice> *> *cachedDevices;

- (void)disconnectDevice:(JSTDevice <JSTPairedDevice> *)device;
- (void)disconnectAllDevices;
- (NSArray <JSTDevice <JSTPairedDevice> *> *)connectedDevicesIncludingNetworkDevices:(BOOL)includingNetworkDevices;

@end

NS_ASSUME_NONNULL_END
