#import "JSTPixelImage.h"
#import "JSTPixelColor.h"
#import "JST_COLOR.h"
#import "JST_IMAGE.h"
#import "JST_POS.h"
#import <CoreGraphics/CoreGraphics.h>
#import <stdlib.h>


static inline JST_IMAGE *create_pixels_image_with_cgimage(CGImageRef cgimg) {
    JST_IMAGE *pixels_image = NULL;
    @autoreleasepool {
        CGSize imgSize = CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg));
        pixels_image = (JST_IMAGE *) malloc(sizeof(JST_IMAGE));
        memset(pixels_image, 0, sizeof(JST_IMAGE));
        pixels_image->width = imgSize.width;
        pixels_image->height = imgSize.height;
        JST_COLOR *pixels = (JST_COLOR *) malloc(imgSize.width * imgSize.height * sizeof(JST_COLOR));
        memset(pixels, 0, imgSize.width * imgSize.height * sizeof(JST_COLOR));
        pixels_image->pixels = pixels;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(pixels, (size_t) imgSize.width, (size_t) imgSize.height, 8, imgSize.width * sizeof(JST_COLOR), colorSpace,
                kCGImageAlphaPremultipliedLast);
        CGContextDrawImage(context, CGRectMake(0, 0, imgSize.width, imgSize.height), cgimg);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
    }
    return pixels_image;
}
#if !TARGET_OS_OSX
static inline JST_IMAGE *create_pixels_image_with_uiimage(UIImage *uiimg) {
    return create_pixels_image_with_cgimage([uiimg CGImage]);
}
#else
static inline JST_IMAGE *create_pixels_image_with_nsimage(NSImage *nsimg) {
    CGSize imgSize = nsimg.size;
    CGRect imgRect = CGRectMake(0, 0, imgSize.width, imgSize.height);
    return create_pixels_image_with_cgimage([nsimg CGImageForProposedRect:&imgRect context:nil hints:nil]);
}
#endif

#define SHIFT_XY_BY_ORIEN_NOM1(X, Y, W, H, O) \
{\
switch (O) {\
int Z;\
case 0:\
break;\
case 1:\
(Z) = (X);\
(X) = (W) - (Y);\
(Y) = (Z);\
break;\
case 2:\
(Z) = (Y);\
(Y) = (H) - (X);\
(X) = (Z);\
break;\
case 3:\
(X) = (W) - (X);\
(Y) = (H) - (Y);\
break;\
}\
}

#define SHIFT_XY_BY_ORIEN(X, Y, W, H, O) SHIFT_XY_BY_ORIEN_NOM1((X), (Y), ((W)-1), ((H)-1), (O))

#define UNSHIFT_XY_BY_ORIEN_NOM1(X, Y, W, H, O) \
{\
switch (O) {\
int Z;\
case 0:\
break;\
case 1:\
(Z) = (Y);\
(Y) = (W) - (X);\
(X) = (Z);\
break;\
case 2:\
(Z) = (X);\
(X) = (H) - (Y);\
(Y) = (Z);\
break;\
case 3:\
(X) = (W) - (X);\
(Y) = (H) - (Y);\
break;\
}\
}

#define UNSHIFT_XY_BY_ORIEN(X, Y, W, H, O) UNSHIFT_XY_BY_ORIEN_NOM1((X), (Y), ((W)-1), ((H)-1), (O))

#define SHIFT_RECT_BY_ORIEN_NOM1(X1, Y1, X2, Y2, W, H, O) \
{\
int Z;\
SHIFT_XY_BY_ORIEN_NOM1((X1), (Y1), (W), (H), (O));\
SHIFT_XY_BY_ORIEN_NOM1((X2), (Y2), (W), (H), (O));\
if ((X1) > (X2)){\
(Z) = (X1);\
(X1) = (X2);\
(X2) = (Z);\
}\
if ((Y1) > (Y2)){\
(Z) = (Y1);\
(Y1) = (Y2);\
(Y2) = (Z);\
}\
}

#define SHIFT_RECT_BY_ORIEN(X1, Y1, X2, Y2, W, H, O) SHIFT_RECT_BY_ORIEN_NOM1((X1), (Y1), (X2), (Y2), (W-1), (H-1), (O))

#define UNSHIFT_RECT_BY_ORIEN_NOM1(X1, Y1, X2, Y2, W, H, O) \
{\
int Z;\
UNSHIFT_XY_BY_ORIEN_NOM1((X1), (Y1), (W), (H), (O));\
UNSHIFT_XY_BY_ORIEN_NOM1((X2), (Y2), (W), (H), (O));\
if ((X1) > (X2)){\
(Z) = (X1);\
(X1) = (X2);\
(X2) = (Z);\
}\
if ((Y1) > (Y2)){\
(Z) = (Y1);\
(Y1) = (Y2);\
(Y2) = (Z);\
}\
}

#define UNSHIFT_RECT_BY_ORIEN(X1, Y1, X2, Y2, W, H, O) UNSHIFT_RECT_BY_ORIEN_NOM1((X1), (Y1), (X2), (Y2), (W-1), (H-1), (O))

#define GET_ROTATE_ROTATE(OO, FO, OUTO) \
{\
switch (FO) {\
case 1:\
switch (OO){\
case 0:\
(OUTO) = 1;\
break;\
case 1:\
(OUTO) = 3;\
break;\
case 2:\
(OUTO) = 0;\
break;\
case 3:\
(OUTO) = 2;\
break;\
}\
break;\
case 2:\
switch (OO){\
case 0:\
(OUTO) = 2;\
break;\
case 1:\
(OUTO) = 0;\
break;\
case 2:\
(OUTO) = 3;\
break;\
case 3:\
(OUTO) = 1;\
break;\
}\
break;\
case 3:\
switch (OO){\
case 0:\
(OUTO) = 3;\
break;\
case 1:\
(OUTO) = 2;\
break;\
case 2:\
(OUTO) = 1;\
break;\
case 3:\
(OUTO) = 0;\
break;\
}\
break;\
case 0:\
(OUTO) = OO;\
}\
}

#define GET_ROTATE_ROTATE2(OO, FO) GET_ROTATE_ROTATE((OO), (FO), (OO))

#define GET_ROTATE_ROTATE3 GET_ROTATE_ROTATE

static inline void get_color_in_pixels_image_safe(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point) {
    SHIFT_XY_BY_ORIEN(x, y, pixels_image->width, pixels_image->height, pixels_image->orientation);
    if (x < pixels_image->width &&
            y < pixels_image->height) {
        color_of_point->the_color = pixels_image->pixels[y * pixels_image->width + x].the_color;
        color_of_point->red = pixels_image->pixels[y * pixels_image->width + x].blue;
        color_of_point->blue = pixels_image->pixels[y * pixels_image->width + x].red;
        return;
    }
    color_of_point->the_color = 0;
}

static inline void set_color_in_pixels_image_safe(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point) {
    SHIFT_XY_BY_ORIEN(x, y, pixels_image->width, pixels_image->height, pixels_image->orientation);
    if (x < pixels_image->width &&
            y < pixels_image->height) {
        pixels_image->pixels[y * pixels_image->width + x].the_color = color_of_point->the_color;
        pixels_image->pixels[y * pixels_image->width + x].red = color_of_point->blue;
        pixels_image->pixels[y * pixels_image->width + x].blue = color_of_point->red;
    }
}

static inline void get_color_in_pixels_image_notran(JST_IMAGE *pixels_image, int x, int y, JST_COLOR *color_of_point) {
    SHIFT_XY_BY_ORIEN(x, y, pixels_image->width, pixels_image->height, pixels_image->orientation);
    color_of_point->the_color = pixels_image->pixels[y * pixels_image->width + x].the_color;
}

static inline CGImageRef create_cgimage_with_pixels_image(JST_IMAGE *pixels_image, JST_COLOR **ppixels_data) /* 这个函数产生的返回值需要释放，第二个参数如果有产出，也需要释放 */
{
    int W, H;
    *ppixels_data = NULL; /* 先把需要产出的这里置空，函数完毕之后需要通过这里判断是否需要释放 */
    JST_COLOR *pixels_buffer = pixels_image->pixels;
    switch (pixels_image->orientation) {
        case 1:
        case 2:
            H = pixels_image->width;
            W = pixels_image->height;
            break;
        default:
            W = pixels_image->width;
            H = pixels_image->height;
            break;
    }
    if (0 != pixels_image->orientation) {
        pixels_buffer = (JST_COLOR *) malloc((size_t) (W * H * 4)); /* 通过第二个参数 ppixels_data 延迟释放，一定要记住 */
        *ppixels_data = pixels_buffer;
        uint64_t big_count_offset = 0;
        JST_COLOR color_of_point;
        for (int y = 0; y < H; ++y) {
            for (int x = 0; x < W; ++x) {
                get_color_in_pixels_image_notran(pixels_image, x, y, &color_of_point);
                pixels_buffer[big_count_offset++].the_color = color_of_point.the_color;
            }
        }
    }
    CGDataProviderRef provider = CGDataProviderCreateWithData(
            NULL, pixels_buffer, (size_t) (4 * W * H), NULL);
    CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wenum-conversion"
    CGImageRef img = CGImageCreate((size_t) W, (size_t) H, 8, (8 * 4), (size_t) (4 * W), cspace,
            kCGImageAlphaPremultipliedLast,
            provider, NULL, true, kCGRenderingIntentDefault);
#pragma clang diagnostic pop
    CFRelease(cspace);
    CFRelease(provider);
    return img;
}

static inline JST_IMAGE *create_pixels_image_with_pixels_image_rect(JST_IMAGE *pixels_image_, uint8_t orien, int x1, int y1, int x2, int y2) {
    JST_IMAGE *pixels_image = NULL;
    @autoreleasepool {
        int old_W = pixels_image_->width;
        int new_W = x2 - x1;
        int new_H = y2 - y1;
        pixels_image = (JST_IMAGE *) malloc(sizeof(JST_IMAGE));
        memset(pixels_image, 0, sizeof(JST_IMAGE));
        pixels_image->width = new_W;
        pixels_image->height = new_H;
        JST_COLOR *pixels = (JST_COLOR *) malloc(new_W * new_H * sizeof(JST_COLOR));
        memset(pixels, 0, new_W * new_H * sizeof(JST_COLOR));
        pixels_image->pixels = pixels;
        uint64_t big_count_offset = 0;
        for (int y = y1; y < y2; ++y) {
            for (int x = x1; x < x2; ++x) {
                pixels[big_count_offset++] = pixels_image_->pixels[y * old_W + x];
            }
        }
        GET_ROTATE_ROTATE3(pixels_image_->orientation, orien, pixels_image->orientation);
    }
    return pixels_image;
}

static inline void free_pixels_image(JST_IMAGE *pixels_image) {
    if (!pixels_image->is_destroyed) {
        free(pixels_image->pixels);
        pixels_image->is_destroyed = 1;
    }
    free(pixels_image);
}

@implementation JSTPixelImage

- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage {
    self = [super init];
    if (self) {
        @autoreleasepool {
            _pixel_image = create_pixels_image_with_cgimage(cgimage);
        }
    }
    return self;
}
#if !TARGET_OS_OSX
+ (JSTPixelImage *)imageWithUIImage:(UIImage *)uiimage {
    return [[[JSTPixelImage alloc] initWithUIImage:uiimage] autorelease];
}
- (JSTPixelImage *)initWithUIImage:(UIImage *)uiimage {
    self = [super init];
    if (self) {
        @autoreleasepool {
            _pixel_image = create_pixels_image_with_uiimage(uiimage);
        }
    }
    return self;
}
- (UIImage *)getUIImage {
    JST_COLOR *pixels_data = NULL;
    CGImageRef cgimg = create_cgimage_with_pixels_image(_pixel_image, &pixels_data);
    if (pixels_data) {
        NSData *imgData = nil;
        @autoreleasepool {
            UIImage *img0 = [UIImage imageWithCGImage:cgimg];
            CFRelease(cgimg);
            imgData = [UIImagePNGRepresentation(img0) retain];
        }
        UIImage *img = [UIImage imageWithData:imgData];
        [imgData release];
        free(pixels_data);
        return img;
    } else {
        UIImage *img0 = [UIImage imageWithCGImage:cgimg];
        CFRelease(cgimg);
        return img0;
    }
}
#else
+ (JSTPixelImage *)imageWithNSImage:(NSImage *)nsimage {
    return [[[JSTPixelImage alloc] initWithNSImage:nsimage] autorelease];
}
- (JSTPixelImage *)initWithNSImage:(NSImage *)nsimage {
    self = [super init];
    if (self) {
        @autoreleasepool {
            _pixel_image = create_pixels_image_with_nsimage(nsimage);
        }
    }
    return self;
}
- (NSImage *)getNSImage {
    JST_COLOR *pixels_data = NULL;
    CGImageRef cgimg = create_cgimage_with_pixels_image(_pixel_image, &pixels_data);
    if (pixels_data) {
        NSData *imgData = nil;
        @autoreleasepool {
            NSBitmapImageRep *newRep = [[[NSBitmapImageRep alloc] initWithCGImage:cgimg] autorelease];
            [newRep setSize:CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg))];
            CFRelease(cgimg);
            imgData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        }
        NSImage *img = [[[NSImage alloc] initWithData:imgData] autorelease];
        [imgData release];
        free(pixels_data);
        return img;
    } else {
        NSImage *img0 = [[[NSImage alloc] initWithCGImage:cgimg size:CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg))] autorelease];
        CFRelease(cgimg);
        return img0;
    }
}
#endif

- (JSTPixelImage *)init {
    self = [super init];
    _pixel_image = NULL;
    return self;
}

- (JSTPixelImage *)crop:(CGRect)rect {
    JSTPixelImage *rectImg = nil;
    @autoreleasepool {
        int x1 = (int) rect.origin.x;
        int y1 = (int) rect.origin.y;
        int x2 = (int) rect.origin.x + (int) rect.size.width;
        int y2 = (int) rect.origin.y + (int) rect.size.height;
        SHIFT_RECT_BY_ORIEN(x1, y1, x2, y2, _pixel_image->width, _pixel_image->height, _pixel_image->orientation);
        y2 = (y2 > _pixel_image->height) ? _pixel_image->height : y2;
        x2 = (x2 > _pixel_image->width) ? _pixel_image->width : x2;
        rectImg = [[JSTPixelImage alloc] init];
        rectImg->_pixel_image = create_pixels_image_with_pixels_image_rect(_pixel_image, 0, x1, y1, x2, y2);
    }
    return [rectImg autorelease];
}

- (CGSize)size {
    int W = 0, H = 0;
    switch (_pixel_image->orientation) {
        case 1:
        case 2:
            H = _pixel_image->width;
            W = _pixel_image->height;
            break;
        default:
            W = _pixel_image->width;
            H = _pixel_image->height;
            break;
    }
    return CGSizeMake(W, H);
}

- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    get_color_in_pixels_image_safe(_pixel_image, (int) point.x, (int) point.y, &color_of_point);
    return [JSTPixelColor colorWithRed:color_of_point.red green:color_of_point.green blue:color_of_point.blue alpha:color_of_point.alpha];
}

- (uint32_t)getColorOfPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    get_color_in_pixels_image_safe(_pixel_image, (int) point.x, (int) point.y, &color_of_point);
    return color_of_point.the_color;
}

- (NSString *)getColorHexOfPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    get_color_in_pixels_image_safe(_pixel_image, (int) point.x, (int) point.y, &color_of_point);
    return [[JSTPixelColor colorWithRed:color_of_point.red green:color_of_point.green blue:color_of_point.blue alpha:color_of_point.alpha] getColorHex];
}

- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    color_of_point.red = color.red;
    color_of_point.green = color.green;
    color_of_point.blue = color.blue;
    color_of_point.alpha = 0xff;
    set_color_in_pixels_image_safe(_pixel_image, (int) point.x, (int) point.y, &color_of_point);
}

- (void)setOrientation:(uint8_t)orientation {
    _pixel_image->orientation = orientation;
}

- (uint8_t)orientation {
    return _pixel_image->orientation;
}

- (void)dealloc {
    free_pixels_image(_pixel_image);
#ifdef DEBUG
    NSLog(@"- [JSTPixelImage dealloc]");
#endif
    [super dealloc];
}

@end
