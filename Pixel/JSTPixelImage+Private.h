#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "JSTPixelImage.h"
//#import "IOSurfaceSPI.h"


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN void get_color_in_pixels_image_safe(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point);
FOUNDATION_EXTERN void set_color_in_pixels_image_safe(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point);

@interface JSTPixelImage (Private)
- (JSTPixelImage *)initWithCompatibleScreenSurface:(IOSurfaceRef)surface colorSpace:(CGColorSpaceRef)colorSpace;
@end

NS_ASSUME_NONNULL_END

