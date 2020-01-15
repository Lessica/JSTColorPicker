#import <TargetConditionals.h>
#if !TARGET_OS_OSX
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface JSTPixelColor : NSObject {
    uint8_t _red;
    uint8_t _green;
    uint8_t _blue;
    uint8_t _alpha;
}
@property uint8_t red;
@property uint8_t green;
@property uint8_t blue;
@property uint8_t alpha;

+ (JSTPixelColor *)colorWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;
+ (JSTPixelColor *)colorWithColor:(uint32_t)color;
+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex;
+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor;
- (uint32_t)getColor;
- (uint32_t)getColorAlpha;
- (uint32_t)color;
- (void)setColor:(uint32_t)color;
- (NSString *)getColorHex;
- (NSString *)getColorHexAlpha;
- (void)setRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha;

#if !TARGET_OS_OSX
+ (JSTPixelColor *)colorWithUIColor:(UIColor *)uicolor;
- (UIColor *)getUIColor;
- (void)setColorWithUIColor:(UIColor *)uicolor;
#else
+ (JSTPixelColor *)colorWithNSColor:(NSColor *)nscolor;
- (NSColor *)getNSColor;
- (void)setColorWithNSColor:(NSColor *)nscolor;
#endif

@end

NS_ASSUME_NONNULL_END

