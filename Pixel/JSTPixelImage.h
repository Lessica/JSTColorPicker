#import <TargetConditionals.h>
#import <AppKit/AppKit.h>
#import "JST_IMAGE.h"


NS_ASSUME_NONNULL_BEGIN

@class JSTPixelColor;

typedef struct JST_IMAGE JST_IMAGE;
@interface JSTPixelImage : NSObject {
    JST_IMAGE *_pixelImage;
}

- (instancetype)init NS_UNAVAILABLE;
- (JSTPixelImage *)initWithInternalPointer:(JST_IMAGE *)pointer;
- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage;
- (JSTPixelImage *)initWithNSImage:(NSImage *)nsimage;
+ (JSTPixelImage *)imageWithNSImage:(NSImage *)nsimage;
- (NSImage *)toNSImage;

@property (nonatomic, assign, readonly) JST_IMAGE *internalPointer;
@property (nonatomic, assign, readonly) CGColorSpaceRef colorSpace;
@property (nonatomic, assign, readonly) CGSize size;
@property (nonatomic, assign, readwrite) uint8_t orientation;

- (JSTPixelImage *)crop:(CGRect)rect;
- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point;
- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point;

- (NSData *)pngRepresentation;
- (NSData *)tiffRepresentation;

@end

NS_ASSUME_NONNULL_END

