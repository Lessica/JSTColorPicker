#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#define SystemImage UIImage
#else
#import <AppKit/AppKit.h>

#define SystemImage NSImage
#endif

#import "JST_IMAGE.h"


NS_ASSUME_NONNULL_BEGIN

@class JSTPixelColor;

typedef struct JST_IMAGE JST_IMAGE;
@interface JSTPixelImage : NSObject {
    JST_IMAGE *_pixelImage;
}

- (instancetype)init NS_UNAVAILABLE;
- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage;
- (JSTPixelImage *)initWithSystemImage:(SystemImage *)systemImage;
+ (JSTPixelImage *)imageWithSystemImage:(SystemImage *)systemImage;
- (JSTPixelImage *)initWithInternalPointer:(JST_IMAGE *)pointer colorSpace:(CGColorSpaceRef)colorSpace;
- (SystemImage *)toSystemImage;

@property (nonatomic, assign, readonly) JST_IMAGE *internalPointer;
@property (nonatomic, assign, readonly) CGColorSpaceRef colorSpace;
@property (nonatomic, assign, readonly) CGSize size;
@property (nonatomic, assign, readwrite) JST_ORIENTATION orientation;

- (JSTPixelImage *)crop:(CGRect)rect;

- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point;
- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point;

- (uint32_t)getColorOfPoint:(CGPoint)point;
- (void)setColor:(uint32_t)color ofPoint:(CGPoint)point;

- (NSData *)pngRepresentation;
#if TARGET_OS_IPHONE
- (NSData *)jpegRepresentationWithCompressionQuality:(CGFloat)compressionQuality;
#else
- (NSData *)tiffRepresentation;
#endif

@end

NS_ASSUME_NONNULL_END

