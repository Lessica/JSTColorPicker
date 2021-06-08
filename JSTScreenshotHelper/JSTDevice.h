//
//  JSTDevice.h
//  JSTColorPicker
//
//  Created by Rachel on 6/7/21.
//  Copyright © 2021 JST. All rights reserved.
//

#import "JSTScreenshotHelperProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface JSTDevice : NSObject

@property (nonatomic, copy, readonly) NSString *base;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *type;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBase:(NSString *)base Name:(NSString *)name Type:(NSString *)type NS_DESIGNATED_INITIALIZER;

- (BOOL)hasValidType;
- (void)setType:(NSString *)type;
- (void)takeScreenshotWithCompletionHandler:(JSTScreenshotHandler)completion;

@end

NS_ASSUME_NONNULL_END
