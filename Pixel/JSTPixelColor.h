#import <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

#define SystemColor UIColor
#else
#import <AppKit/AppKit.h>

#define SystemColor NSColor
#endif


NS_ASSUME_NONNULL_BEGIN

@interface JSTPixelColor : NSObject <NSSecureCoding, NSCopying> {
    uint8_t _red;
    uint8_t _green;
    uint8_t _blue;
    uint8_t _alpha;
}

@property (assign, readonly) uint8_t red;
@property (assign, readonly) uint8_t green;
@property (assign, readonly) uint8_t blue;
@property (assign, readonly) uint8_t alpha;
@property (assign, readonly) uint32_t rgbValue;
@property (assign, readonly) uint32_t rgbaValue;

@property (copy, readonly) NSString *hexString;
@property (copy, readonly) NSString *hexStringWithAlpha;
@property (copy, readonly) NSString *cssString;
@property (copy, readonly) NSString *cssRGBAString;

/* Color Space Independent */
+ (JSTPixelColor *)colorWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;
+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex;
+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor;
- (void)setRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;

/* Color Space Related */
+ (JSTPixelColor *)colorWithSystemColor:(SystemColor *)systemColor;
- (void)setColorWithSystemColor:(SystemColor *)systemColor;
- (SystemColor *)toSystemColorWithColorSpace:(NSColorSpace *)colorSpace;

@end

NS_ASSUME_NONNULL_END

