//
//  JSTScreenshotHelperProtocol.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSTXPCDevice.h"

NS_ASSUME_NONNULL_BEGIN

@protocol JSTScreenshotHelperProtocol

- (void)setIncludingNetworkDevices:(BOOL)includingNetworkDevices;
- (NSArray <JSTXPCDevice *> *)discoveredDevices;
- (void)takeScreenshot:(JSTXPCDevice *)aDevice withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply;

@end

NS_ASSUME_NONNULL_END
