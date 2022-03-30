//
//  SPUStandardUpdaterController.m
//  JSTColorPicker
//
//  Created by Darwin on 3/18/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "SPUStandardUpdaterController.h"
#import <Sparkle/SPUUpdaterSettings.h>

#if APP_STORE
@implementation SPUStandardUpdaterController

- (void)checkForUpdates:(id)sender { }

@end
#else
@implementation SPUStandardUpdaterController (Settings)

- (BOOL)automaticallyChecksForUpdates {
    SPUUpdaterSettings *settings = [[SPUUpdaterSettings alloc] initWithHostBundle:[NSBundle mainBundle]];
    return settings.automaticallyChecksForUpdates;
}

@end
#endif
