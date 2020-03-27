//
//  JSTLoginItem.h
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/27/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JSTLoginItem : NSObject
+ (BOOL)willLaunchAtLogin:(NSURL *)itemURL;
+ (void)setLaunchAtLogin:(NSURL *)itemURL enabled:(BOOL)enabled;
@end

NS_ASSUME_NONNULL_END
