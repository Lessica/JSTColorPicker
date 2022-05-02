//
//  OpenCVWrapper.mm
//  JSTColorPicker
//
//  Created by Darwin on 5/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "OpenCVWrapper.h"
#import "NSImage+OpenCV.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc/imgproc_c.h>


//using namespace std;

@implementation OpenCVWrapper

+ (CGRect)bestChildRectangleOf:(NSImage * _Nonnull)image {
    
    cv::Mat imageMat = [image CVMat];
    
    std::vector <std::vector<cv::Point>> rectangles;
    std::vector <cv::Point> bestChildRectangle;
    
    OpenCVWrapper_GetRectangles(imageMat, rectangles);
    OpenCVWrapper_GuessBestChildRectangle(cv::Rect(0, 0, image.size.width, image.size.height), rectangles, bestChildRectangle);
    
    if (bestChildRectangle.size() != 4) {
        imageMat.release();
        return CGRectNull;
    }
    
    cv::Rect bestChildRect = cv::boundingRect(cv::Mat(bestChildRectangle));
    return CGRectMake(bestChildRect.x, bestChildRect.y, bestChildRect.width, bestChildRect.height);
    
}

// http://stackoverflow.com/questions/8667818/opencv-c-obj-c-detecting-a-sheet-of-paper-square-detection
static void OpenCVWrapper_GetRectangles(cv::Mat& image, std::vector<std::vector<cv::Point>>&rectangles) {
    
    // blur will enhance edge detection
    cv::Mat blurred(image);
    cv::medianBlur(image, blurred, 9);
    
    cv::Mat gray0(blurred.size(), CV_8U), gray;
    std::vector<std::vector<cv::Point>> contours;
    
    // find squares in every color plane of the image
    for (int c = 0; c < 3; c++)
    {
        int ch[] = {c, 0};
        cv::mixChannels(&blurred, 1, &gray0, 1, ch, 1);
        
        // try several threshold levels
        const int threshold_level = 2;
        for (int l = 0; l < threshold_level; l++)
        {
            // Use Canny instead of zero threshold level!
            // Canny helps to catch squares with gradient shading
            if (l == 0)
            {
                
                cv::Canny(gray0, gray, 10 /* threshold1 */, 20 /* threshold2 */, 3 /* apertureSize */, true);
                
                // Dilate helps to remove potential holes between edge segments
                cv::dilate(gray, gray, cv::Mat(), cv::Point(-1, -1));
                
            }
            else
            {
                gray = gray0 >= (l + 1) * 255 / threshold_level;
            }
            
            // Find contours and store them in a list
            cv::findContours(gray, contours, CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE);
            
            // Test contours
            std::vector<cv::Point> approx;
            for (size_t i = 0; i < contours.size(); i++)
            {
                // approximate contour with accuracy proportional
                // to the contour perimeter
                cv::approxPolyDP(cv::Mat(contours[i]), approx, arcLength(cv::Mat(contours[i]), true) * 0.02 /* epsilon */, true);
                
                // Note: absolute value of an area is used because
                // area may be positive or negative - in accordance with the
                // contour orientation
                if (approx.size() == 4 &&
                    fabs(cv::contourArea(cv::Mat(approx))) > 1000 &&
                    cv::isContourConvex(cv::Mat(approx)))
                {
                    double maxCosine = 0;
                    
                    for (int j = 2; j < 5; j++)
                    {
                        double cosine = fabs(OpenCVWrapper_Angle(approx[j % 4], approx[j - 2], approx[j - 1]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    
                    if (maxCosine < 0.3) {
                        rectangles.push_back(approx);
                    }
                }
            }
        }
    }
    
}

static void OpenCVWrapper_GuessBestChildRectangle(const cv::Rect rect, const std::vector<std::vector<cv::Point>>& rectangles, std::vector<cv::Point>& largestRectangle)
{
    if (!rectangles.size()) {
        return;
    }
    
    double maxArea = 0;
    size_t index = 0;
    
    for (size_t i = 0; i < rectangles.size(); i++)
    {
        cv::Rect rectangle = cv::boundingRect(cv::Mat(rectangles[i]));
        double area = rectangle.width * rectangle.height;
                
        if (maxArea < area && rect != rectangle) {
            maxArea = area;
            index = i;
        }
    }
    
    largestRectangle = rectangles[index];
}

static double OpenCVWrapper_Angle(cv::Point pt1, cv::Point pt2, cv::Point pt0) {
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1 * dx2 + dy1 * dy2) / sqrt((dx1 * dx1 + dy1 * dy1) * (dx2 * dx2 + dy2 * dy2) + 1e-10);
}

+ (NSImage *)transformedImageOf:(NSImage *)image toSize:(CGSize)newSize withCorners:(CGPoint [4])corners {
    
    cv::Mat imageMat = [image CVMat];
    cv::Mat newImageMat = cv::Mat(cvSize(newSize.width, newSize.height), CV_8UC4);
    
    cv::Point2f src[4], dst[4];
    src[0].x = corners[0].x;
    src[0].y = corners[0].y;
    src[1].x = corners[1].x;
    src[1].y = corners[1].y;
    src[2].x = corners[2].x;
    src[2].y = corners[2].y;
    src[3].x = corners[3].x;
    src[3].y = corners[3].y;
    
    dst[0].x = 0;
    dst[0].y = 0;
    dst[1].x = newSize.width - 1;
    dst[1].y = 0;
    dst[2].x = newSize.width - 1;
    dst[2].y = newSize.height - 1;
    dst[3].x = 0;
    dst[3].y = newSize.height - 1;
 
    cv::warpPerspective(imageMat, newImageMat, cv::getPerspectiveTransform(src, dst), cvSize(newSize.width, newSize.height));
    
    return [NSImage imageWithCVMat:newImageMat];
}

@end

