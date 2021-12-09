//
//  JSTPairedDeviceService.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSTScreenshotHelperProtocol.h"
#import "JSTPairedDevice.h"

NS_ASSUME_NONNULL_BEGIN

@class JSTPairedDeviceStore;

@interface JSTPairedDeviceService : NSObject <JSTScreenshotHelperProtocol>
@property (nonatomic, strong, readonly) JSTPairedDeviceStore *deviceService;
- (void)disconnectDevice:(JSTDevice <JSTPairedDevice> *)device;
- (void)disconnectAllDevices;
@end

NS_ASSUME_NONNULL_END
