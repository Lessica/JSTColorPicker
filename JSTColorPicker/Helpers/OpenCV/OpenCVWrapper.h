//
//  OpenCVWrapper.h
//  JSTColorPicker
//
//  Created by Darwin on 5/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject
+ (CGRect)bestChildRectangleOf:(NSImage * _Nonnull)image;
+ (NSImage *)transformedImageOf:(NSImage *)image toSize:(CGSize)newSize withCorners:(CGPoint [_Nonnull 4])corners;
@end

NS_ASSUME_NONNULL_END
