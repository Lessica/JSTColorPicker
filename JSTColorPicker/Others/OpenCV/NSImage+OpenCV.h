//
//  NSImage+OpenCV.h
//  JSTColorPicker
//
//  Created by Darwin on 5/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <opencv2/opencv.hpp>


NS_ASSUME_NONNULL_BEGIN

@interface NSImage (OpenCV)

+ (NSImage *)imageWithCVMat:(const cv::Mat &)cvMat;
- (instancetype)initWithCVMat:(const cv::Mat &)cvMat;

@property (nonatomic, readonly) cv::Mat CVMat;
@property (nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end

NS_ASSUME_NONNULL_END

