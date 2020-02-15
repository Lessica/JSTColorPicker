//
//  JSTDeviceService.h
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libimobiledevice/libimobiledevice.h>

NS_ASSUME_NONNULL_BEGIN

@class JSTDeviceService, JSTDevice;

@protocol JSTDeviceDelegate <NSObject>
- (void)didReceiveiDeviceEvent:(JSTDeviceService *)service;
@end

@interface JSTDeviceService : NSObject

@property (nonatomic, weak) id <JSTDeviceDelegate> delegate;
@property (nonatomic, strong) NSArray <JSTDevice *> *devices;

@end

NS_ASSUME_NONNULL_END
