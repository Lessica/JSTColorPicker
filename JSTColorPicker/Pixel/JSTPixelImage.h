#import <TargetConditionals.h>
#import <AppKit/AppKit.h>


NS_ASSUME_NONNULL_BEGIN

@class JSTPixelColor;

typedef struct JST_IMAGE JST_IMAGE;
@interface JSTPixelImage : NSObject {
    JST_IMAGE *_pixel_image;
}
@property uint8_t orientation;

- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage;
- (JSTPixelImage *)initWithNSImage:(NSImage *)nsimage;
+ (JSTPixelImage *)imageWithNSImage:(NSImage *)nsimage;
- (NSImage *)toNSImage;

- (CGSize)size;

- (JSTPixelImage *)crop:(CGRect)rect;
- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point;
- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point;

- (NSData *)pngRepresentation;
- (NSData *)tiffRepresentation;

@end

NS_ASSUME_NONNULL_END

