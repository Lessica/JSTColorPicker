//
//  OpenCVWrapper.h
//  CamScanner
//
//  Created by Srinija on 16/05/17.
//  Copyright © 2017 Srinija Ammapalli. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface OpenCVWrapper : NSObject
+ (NSMutableArray <NSValue *> *)largestSquarePointsOf:(NSImage *)image :(CGSize)size;
+ (NSImage *)transformedImage:(CGFloat)newWidth :(CGFloat)newHeight :(NSImage *)origImage :(CGPoint [4])corners :(CGSize)size;
@end

