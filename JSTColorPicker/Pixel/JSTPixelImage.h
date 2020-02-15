#import <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class JSTPixelColor;

typedef struct JST_IMAGE JST_IMAGE;
@interface JSTPixelImage : NSObject {
    JST_IMAGE *_pixel_image;
}
@property uint8_t orientation;

- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage;

#if !TARGET_OS_OSX
- (JSTPixelImage *)initWithUIImage:(UIImage *)uiimage;
+ (JSTPixelImage *)imageWithUIImage:(UIImage *)uiimage;
- (UIImage *)toUIImage;
#else
- (JSTPixelImage *)initWithNSImage:(NSImage *)nsimage;
+ (JSTPixelImage *)imageWithNSImage:(NSImage *)nsimage;
- (NSImage *)toNSImage;
#endif

- (CGSize)size;

- (JSTPixelImage *)crop:(CGRect)rect;
- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point;
- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point;

- (NSData *)pngRepresentation;
- (NSData *)tiffRepresentation;

@end

NS_ASSUME_NONNULL_END

