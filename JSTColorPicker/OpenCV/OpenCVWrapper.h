//
//  OpenCVWrapper.h
//  JSTColorPicker
//
//  Created by Darwin on 5/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface OpenCVWrapper : NSObject
+ (NSMutableArray <NSValue *> *)largestSquarePointsOf:(NSImage *)image :(CGSize)size;
+ (NSImage *)transformedImage:(CGFloat)newWidth :(CGFloat)newHeight :(NSImage *)origImage :(CGPoint [4])corners :(CGSize)size;
@end

