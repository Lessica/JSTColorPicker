#import "JSTPixelColor.h"
#import "JST_COLOR.h"


@implementation JSTPixelColor

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    uint8_t red   = (uint8_t)[coder decodeIntForKey:@"red"];
    uint8_t green = (uint8_t)[coder decodeIntForKey:@"green"];
    uint8_t blue  = (uint8_t)[coder decodeIntForKey:@"blue"];
    uint8_t alpha = (uint8_t)[coder decodeIntForKey:@"alpha"];
    return [self initWithRed:red green:green blue:blue alpha:alpha];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:(int)self.red forKey:@"red"];
    [coder encodeInt:(int)self.green forKey:@"green"];
    [coder encodeInt:(int)self.blue forKey:@"blue"];
    [coder encodeInt:(int)self.alpha forKey:@"alpha"];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return [[JSTPixelColor alloc] initWithJSTColor:self];
}

+ (JSTPixelColor *)colorWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha
{
    return [[JSTPixelColor alloc] initWithRed:red green:green blue:blue alpha:alpha];
}

+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex
{
    return [[JSTPixelColor alloc] initWithColorHex:hex];
}

+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor
{
    return [[JSTPixelColor alloc] initWithJSTColor:jstcolor];
}

- (uint32_t)rgbaValue
{
    JST_COLOR color;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    color.alpha = _alpha;
    return color.the_color;
}

- (uint32_t)rgbValue
{
    JST_COLOR color;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    color.alpha = 0;
    return color.the_color;
}

- (NSString *)hexStringWithAlpha
{
    JST_COLOR color;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    color.alpha = _alpha;
    return [NSString stringWithFormat:@"0x%08x", color.the_color];
}

- (NSString *)hexString
{
    JST_COLOR color;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    color.alpha = 0;
    return [NSString stringWithFormat:@"0x%06x", color.the_color];
}

- (NSString *)cssString
{
    JST_COLOR color;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    color.alpha = 0;
    return [NSString stringWithFormat:@"#%06X", color.the_color];
}

- (NSString *)cssRGBAString
{
    return [NSString stringWithFormat:@"rgba(%d,%d,%d,%.2f)", self.red, self.green, self.blue, (float)self.alpha / 0xff];
}

- (JSTPixelColor *)init
{
    if (self = [super init]) {
        _red = 0;
        _green = 0;
        _blue = 0;
        _alpha = 0;
    }
    return self;
}

- (JSTPixelColor *)initWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha
{
    self = [self init];
    [self setRed:red green:green blue:blue alpha:alpha];
    return self;
}

- (JSTPixelColor *)initWithColorHex:(NSString *)hex
{
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    } else if ([hex hasPrefix:@"0x"]) {
        hex = [hex substringFromIndex:2];
    }
    NSUInteger length = hex.length;
    if (length != 3 && length != 6 && length != 8)
        return nil;
    if (length == 3) {
        NSString *r = [hex substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [hex substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [hex substringWithRange:NSMakeRange(2, 1)];
        hex = [NSString stringWithFormat:@"%@%@%@%@%@%@ff", r, r, g, g, b, b];
    } else if (length == 6) {
        hex = [NSString stringWithFormat:@"%@ff", hex];
    }
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    unsigned int rgbaValue = 0;
    [scanner scanHexInt:&rgbaValue];
    return [self initWithRed:(uint8_t) (((rgbaValue & 0xFF000000) >> 24) / 255.f)
                       green:(uint8_t) (((rgbaValue & 0xFF0000) >> 16) / 255.f)
                        blue:(uint8_t) (((rgbaValue & 0xFF00) >> 8) / 255.f)
                       alpha:(uint8_t) (((rgbaValue & 0xFF)) / 255.f)];
}

- (JSTPixelColor *)initWithJSTColor:(JSTPixelColor *)jstcolor
{
    return [self initWithRed:jstcolor.red green:jstcolor.green blue:jstcolor.blue alpha:jstcolor.alpha];
}

- (void)setRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha
{
    _red = red;
    _green = green;
    _blue = blue;
    _alpha = alpha;
}

- (uint8_t)red
{
    return _red;
}

- (void)setRed:(uint8_t)red
{
    _red = red;
}

- (uint8_t)green
{
    return _green;
}

- (void)setGreen:(uint8_t)green
{
    _green = green;
}

- (uint8_t)blue
{
    return _blue;
}

- (void)setBlue:(uint8_t)blue
{
    _blue = blue;
}

- (uint8_t)alpha
{
    return _alpha;
}

- (void)setAlpha:(uint8_t)alpha
{
    _alpha = alpha;
}

- (JSTPixelColor *)initWithSystemColor:(SystemColor *)systemColor
{
    self = [self init];
    if (self) {
        [self setColorWithSystemColor:systemColor];
    }
    return self;
}

+ (JSTPixelColor *)colorWithSystemColor:(SystemColor *)systemColor
{
    return [[JSTPixelColor alloc] initWithSystemColor:systemColor];
}

- (NSString *)description {
    return self.cssString;
}

- (SystemColor *)toSystemColorWithColorSpace:(NSColorSpace *)colorSpace
{
    NSAssert(colorSpace.colorSpaceModel == NSColorSpaceModelRGB || colorSpace.colorSpaceModel == NSColorSpaceModelGray,
             @"unsupported color model");
    if (colorSpace.colorSpaceModel == NSColorSpaceModelRGB) {
        CGFloat components[4];
        components[0] = (CGFloat)_red / 255.f;
        components[1] = (CGFloat)_green / 255.f;
        components[2] = (CGFloat)_blue / 255.f;
        components[3] = (CGFloat)_alpha / 255.f;
        return [SystemColor colorWithColorSpace:colorSpace components:components count:4];
    } else {
        CGFloat _gray = 0.299 * (CGFloat)_red / 255.f + 0.587 * (CGFloat)_green / 255.f + 0.114 * (CGFloat)_blue / 255.f;
        CGFloat components[2];
        components[0] = (CGFloat)_gray / 255.f;
        components[1] = (CGFloat)_alpha / 255.f;
        return [SystemColor colorWithColorSpace:colorSpace components:components count:2];
    }
}

- (void)setColorWithSystemColor:(SystemColor *)systemColor
{
    NSDictionary *colorDic = [self getRGBDictionaryFromSystemColor:systemColor];
    _red = (uint8_t)([colorDic[@"R"] floatValue] * 255);
    _green = (uint8_t)([colorDic[@"G"] floatValue] * 255);
    _blue = (uint8_t)([colorDic[@"B"] floatValue] * 255);
    _alpha = (uint8_t)([colorDic[@"A"] floatValue] * 255);
}

- (NSDictionary *)getRGBDictionaryFromSystemColor:(SystemColor *)systemColor
{
    NSAssert(systemColor.colorSpace.colorSpaceModel == NSColorSpaceModelRGB || systemColor.colorSpace.colorSpaceModel == NSColorSpaceModelGray,
             @"unsupported color model");
    CGFloat r = 0, g = 0, b = 0, a = 0, w = 0;
    if (systemColor.numberOfComponents == 4) {
        if ([self respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
            [systemColor getRed:&r green:&g blue:&b alpha:&a];
        } else {
            const CGFloat *components = CGColorGetComponents(systemColor.CGColor);
            r = components[0];
            g = components[1];
            b = components[2];
            a = components[3];
        }
    } else if (systemColor.numberOfComponents == 2) {
        if ([self respondsToSelector:@selector(getWhite:alpha:)]) {
            [systemColor getWhite:&w alpha:&a];
            r = w;
            g = w;
            b = w;
        } else {
            const CGFloat *components = CGColorGetComponents(systemColor.CGColor);
            r = components[0];
            g = components[0];
            b = components[0];
            a = components[1];
        }
    }
    return @{
        @"R":@(r),
        @"G":@(g),
        @"B":@(b),
        @"A":@(a),
    };
}

@end
