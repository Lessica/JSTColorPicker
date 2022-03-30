//
//  SPUStandardUpdaterController.h
//  JSTColorPicker
//
//  Created by Darwin on 3/18/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#if !APP_STORE
#import <Sparkle/SPUStandardUpdaterController.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#if APP_STORE
@interface SPUStandardUpdaterController : NSObject

@end
#else
@interface SPUStandardUpdaterController (Settings)
@property (assign, readonly) BOOL automaticallyChecksForUpdates;
@end
#endif

NS_ASSUME_NONNULL_END
