#import <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface JSTPixelColor : NSObject <NSCoding, NSCopying> {
    uint8_t _red;
    uint8_t _green;
    uint8_t _blue;
    uint8_t _alpha;
}
@property (assign, readonly) uint8_t red;
@property (assign, readonly) uint8_t green;
@property (assign, readonly) uint8_t blue;
@property (assign, readonly) uint8_t alpha;
@property (assign, readonly) uint32_t intValue;
@property (assign, readonly) uint32_t intValueWithAlpha;
@property (assign) uint32_t underlyingColor;
@property (copy, readonly) NSString *hexString;
@property (copy, readonly) NSString *hexStringWithAlpha;
@property (copy, readonly) NSString *cssString;

+ (JSTPixelColor *)colorWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;
+ (JSTPixelColor *)colorWithColor:(uint32_t)color;
+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex;
+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor;
- (void)setRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;

#if !TARGET_OS_OSX
+ (JSTPixelColor *)colorWithUIColor:(UIColor *)uicolor;
- (UIColor *)toUIColor;
- (void)setColorWithUIColor:(UIColor *)uicolor;
#else
+ (JSTPixelColor *)colorWithNSColor:(NSColor *)nscolor;
- (NSColor *)toNSColor;
- (void)setColorWithNSColor:(NSColor *)nscolor;
#endif

@end

NS_ASSUME_NONNULL_END

