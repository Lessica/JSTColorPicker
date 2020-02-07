#import "JSTPixelColor.h"
#import "JST_COLOR.h"


@implementation JSTPixelColor

- (instancetype)initWithCoder:(NSCoder *)coder {
    uint8_t red   = (uint8_t)[coder decodeIntForKey:@"red"];
    uint8_t green = (uint8_t)[coder decodeIntForKey:@"green"];
    uint8_t blue  = (uint8_t)[coder decodeIntForKey:@"blue"];
    uint8_t alpha = (uint8_t)[coder decodeIntForKey:@"alpha"];
    return [self initWithRed:red green:green blue:blue alpha:alpha];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:(int)self.red   forKey:@"red"];
    [coder encodeInt:(int)self.green forKey:@"green"];
    [coder encodeInt:(int)self.blue  forKey:@"blue"];
    [coder encodeInt:(int)self.alpha forKey:@"alpha"];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return [[JSTPixelColor alloc] initWithJSTColor:self];
}

+ (JSTPixelColor *)colorWithRed:(uint8_t)red green:(uint8_t)green blue:(uint8_t)blue alpha:(uint8_t)alpha
{
    return [[JSTPixelColor alloc] initWithRed:red green:green blue:blue alpha:alpha];
}

+ (JSTPixelColor *)colorWithColor:(uint32_t)color
{
    return [[JSTPixelColor alloc] initWithColor:color];
}

+ (JSTPixelColor *)colorWithColorHex:(NSString *)hex
{
    return [[JSTPixelColor alloc] initWithColorHex:hex];
}

+ (JSTPixelColor *)colorWithJSTColor:(JSTPixelColor *)jstcolor
{
    return [[JSTPixelColor alloc] initWithJSTColor:jstcolor];
}

- (uint32_t)intValueWithAlpha
{
    JST_COLOR color;
    color.red = _red;
    color.green = _green;
    color.blue = _blue;
    color.alpha = _alpha;
    return color.the_color;
}

- (uint32_t)underlyingColor {
    return [self intValueWithAlpha];
}

- (uint32_t)intValue
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

- (JSTPixelColor *)initWithColor:(uint32_t)color
{
    JST_COLOR c;
    c.the_color = color;
    return [self initWithRed:c.red green:c.green blue:c.blue alpha:c.alpha];
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

- (void)setUnderlyingColor:(uint32_t)color
{
    JST_COLOR c;
    c.the_color = color;
    [self setRed:c.red green:c.green blue:c.blue alpha:c.alpha];
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

#if !TARGET_OS_OSX
- (JSTPixelColor *)initWithUIColor:(UIColor *)uicolor
{
    self = [self init];
    [self setColorWithUIColor:uicolor];
    return self;
}
+ (JSTPixelColor *)colorWithUIColor:(UIColor *)uicolor
{
    return [[[JSTPixelColor alloc] initWithUIColor:uicolor] autorelease];
}
- (UIColor *)toUIColor
{
    return [UIColor colorWithRed:((CGFloat)_red)/255.0f green:((CGFloat)_green)/255.0f blue:((CGFloat)_blue)/255.0f alpha:((CGFloat)_alpha)/255.0f];
}
- (void)setColorWithUIColor:(UIColor *)uicolor
{
    @autoreleasepool {
        NSDictionary *colorDic = [self getRGBDictionaryByUIColor:uicolor];
        _red = (uint8_t)([colorDic[@"R"] floatValue] * 255);
        _green = (uint8_t)([colorDic[@"G"] floatValue] * 255);
        _blue = (uint8_t)([colorDic[@"B"] floatValue] * 255);
        _alpha = (uint8_t)([colorDic[@"A"] floatValue] * 255);
    }
}
- (NSDictionary *)getRGBDictionaryByUIColor:(UIColor *)originColor
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([self respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
        [originColor getRed:&r green:&g blue:&b alpha:&a];
    }
    else {
        const CGFloat *components = CGColorGetComponents(originColor.CGColor);
        r = components[0];
        g = components[1];
        b = components[2];
        a = components[3];
    }
    return @{@"R":@(r),
             @"G":@(g),
             @"B":@(b),
             @"A":@(a)};
}
#else
- (JSTPixelColor *)initWithNSColor:(NSColor *)nscolor
{
    self = [self init];
    if (self) {
        [self setColorWithNSColor:nscolor];
    }
    return self;
}
+ (JSTPixelColor *)colorWithNSColor:(NSColor *)nscolor
{
    return [[JSTPixelColor alloc] initWithNSColor:nscolor];
}
- (NSColor *)toNSColor
{
    return [NSColor colorWithRed:((CGFloat)_red)/255.0f green:((CGFloat)_green)/255.0f blue:((CGFloat)_blue)/255.0f alpha:((CGFloat)_alpha)/255.0f];
}
- (void)setColorWithNSColor:(NSColor *)nscolor
{
    @autoreleasepool {
        NSDictionary *colorDic = [self getRGBDictionaryByNSColor:nscolor];
        _red = (uint8_t)([colorDic[@"R"] floatValue] * 255);
        _green = (uint8_t)([colorDic[@"G"] floatValue] * 255);
        _blue = (uint8_t)([colorDic[@"B"] floatValue] * 255);
        _alpha = (uint8_t)([colorDic[@"A"] floatValue] * 255);
    }
}
- (NSDictionary *)getRGBDictionaryByNSColor:(NSColor *)originColor
{
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([self respondsToSelector:@selector(getRed:green:blue:alpha:)]) {
        [originColor getRed:&r green:&g blue:&b alpha:&a];
    }
    else {
        const CGFloat *components = CGColorGetComponents(originColor.CGColor);
        r = components[0];
        g = components[1];
        b = components[2];
        a = components[3];
    }
    return @{@"R":@(r),
             @"G":@(g),
             @"B":@(b),
             @"A":@(a)};
}
#endif

- (NSString *)description {
    return self.cssString;
}

@end
