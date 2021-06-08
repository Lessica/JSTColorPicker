//
//  JSTPairedDeviceService.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSTScreenshotHelperProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class JSTPairedDevice, JSTPairedDeviceStore;

@interface JSTPairedDeviceService : NSObject <JSTScreenshotHelperProtocol>
@property (nonatomic, strong, readonly) JSTPairedDeviceStore *deviceService;
- (void)disconnectDevice:(JSTPairedDevice *)device;
- (void)disconnectAllDevices;
@end

NS_ASSUME_NONNULL_END
