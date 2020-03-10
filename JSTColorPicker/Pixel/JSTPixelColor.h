#import <TargetConditionals.h>
#import <AppKit/AppKit.h>


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

+ (JSTPixelColor *)colorWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;
+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex;
+ (JSTPixelColor *)colorWithNSColor:(NSColor *)nscolor;
+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor;

- (void)setRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;
- (NSColor *)toNSColor;
- (void)setColorWithNSColor:(NSColor *)nscolor;

@end

NS_ASSUME_NONNULL_END

