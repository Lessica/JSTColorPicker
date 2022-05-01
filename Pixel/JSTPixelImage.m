#import "JSTPixelImage.h"
#import "JSTPixelColor.h"
#import "JST_POS.h"
#import "JST_COLOR.h"

#import <stdlib.h>
#import <CoreGraphics/CoreGraphics.h>


#pragma mark - NSImage (Compatibility)

@interface NSImage (Compatibility)

/**
 The underlying Core Graphics image object. This will actually use `CGImageForProposedRect` with the image size.
 */
@property (nonatomic, readonly, nullable) CGImageRef CGImage;
/**
 The scale factor of the image. This wil actually use `bestRepresentationForRect` with image size and pixel size to calculate the scale factor. If failed, use the default value 1.0. Should be greater than or equal to 1.0.
 */
@property (nonatomic, readonly) CGFloat scale;

// These are convenience methods to make AppKit's `NSImage` match UIKit's `UIImage` behavior. The scale factor should be greater than or equal to 1.0.

/**
 Returns an image object with the scale factor and orientation. The representation is created from the Core Graphics image object.
 @note The difference between this and `initWithCGImage:size` is that `initWithCGImage:size` will actually create a `NSCGImageSnapshotRep` representation and always use `backingScaleFactor` as scale factor. So we should avoid it and use `NSBitmapImageRep` with `initWithCGImage:` instead.
 @note The difference between this and UIKit's `UIImage` equivalent method is the way to process orientation. If the provided image orientation is not equal to Up orientation, this method will firstly rotate the CGImage to the correct orientation to work compatible with `NSImageView`. However, UIKit will not actually rotate CGImage and just store it as `imageOrientation` property.
 @param cgImage A Core Graphics image object
 @param scale The image scale factor
 @param orientation The orientation of the image data
 @return The image object
 */
- (nonnull instancetype)initWithCGImage:(nonnull CGImageRef)cgImage scale:(CGFloat)scale orientation:(CGImagePropertyOrientation)orientation;

/**
 Returns an image object with the scale factor. The representation is created from the image data.
 @note The difference between these this and `initWithData:` is that `initWithData:` will always use `backingScaleFactor` as scale factor.
 @param data The image data
 @param scale The image scale factor
 @return The image object
 */
- (nullable instancetype)initWithData:(nonnull NSData *)data scale:(CGFloat)scale;

@end

static inline CGAffineTransform SDCGContextTransformFromOrientation(CGImagePropertyOrientation orientation, CGSize size) {
    // Inspiration from @libfeihu
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (orientation) {
        case kCGImagePropertyOrientationDown:
        case kCGImagePropertyOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, size.width, size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case kCGImagePropertyOrientationLeft:
        case kCGImagePropertyOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case kCGImagePropertyOrientationRight:
        case kCGImagePropertyOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case kCGImagePropertyOrientationUp:
        case kCGImagePropertyOrientationUpMirrored:
            break;
    }
    
    switch (orientation) {
        case kCGImagePropertyOrientationUpMirrored:
        case kCGImagePropertyOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case kCGImagePropertyOrientationLeftMirrored:
        case kCGImagePropertyOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case kCGImagePropertyOrientationUp:
        case kCGImagePropertyOrientationDown:
        case kCGImagePropertyOrientationLeft:
        case kCGImagePropertyOrientationRight:
            break;
    }
    
    return transform;
}

@implementation NSImage (Compatibility)

+ (BOOL)CGImageContainsAlpha:(CGImageRef)cgImage {
    if (!cgImage) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}

+ (CGColorSpaceRef)colorSpaceGetDeviceRGB {
    CGColorSpaceRef screenColorSpace = NSScreen.mainScreen.colorSpace.CGColorSpace;
    if (screenColorSpace) {
        return screenColorSpace;
    }
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}

+ (CGImageRef)CGImageCreateDecoded:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation {
    if (!cgImage) {
        return NULL;
    }
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return NULL;
    size_t newWidth;
    size_t newHeight;
    switch (orientation) {
        case kCGImagePropertyOrientationLeft:
        case kCGImagePropertyOrientationLeftMirrored:
        case kCGImagePropertyOrientationRight:
        case kCGImagePropertyOrientationRightMirrored: {
            // These orientation should swap width & height
            newWidth = height;
            newHeight = width;
        }
            break;
        default: {
            newWidth = width;
            newHeight = height;
        }
            break;
    }
    
    BOOL hasAlpha = NO /* [self CGImageContainsAlpha:cgImage] */;
    // iOS prefer BGRA8888 (premultiplied) or BGRX8888 bitmapInfo for screen rendering, which is same as `UIGraphicsBeginImageContext()` or `- [CALayer drawInContext:]`
    // Though you can use any supported bitmapInfo (see: https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB ) and let Core Graphics reorder it when you call `CGContextDrawImage`
    // But since our build-in coders use this bitmapInfo, this can have a little performance benefit
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    CGContextRef context = CGBitmapContextCreate(NULL, newWidth, newHeight, 8, 0, [self colorSpaceGetDeviceRGB], bitmapInfo);
    if (!context) {
        return NULL;
    }
    
    // Apply transform
    CGAffineTransform transform = SDCGContextTransformFromOrientation(orientation, CGSizeMake(newWidth, newHeight));
    CGContextConcatCTM(context, transform);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage); // The rect is bounding box of CGImage, don't swap width & height
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    return newImageRef;
}

- (nullable CGImageRef)CGImage {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    CGImageRef cgImage = [self CGImageForProposedRect:&imageRect context:nil hints:nil];
    return cgImage;
}

- (CGFloat)scale {
    CGFloat scale = 1;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    CGFloat width = imageRep.size.width;
    CGFloat height = imageRep.size.height;
    NSUInteger pixelWidth = imageRep.pixelsWide;
    NSUInteger pixelHeight = imageRep.pixelsHigh;
    if (width > 0 && height > 0) {
        CGFloat widthScale = pixelWidth / width;
        CGFloat heightScale = pixelHeight / height;
        if (widthScale == heightScale && widthScale >= 1) {
            // Protect because there may be `NSImageRepMatchesDevice` (0)
            scale = widthScale;
        }
    }
    
    return scale;
}

- (instancetype)initWithCGImage:(nonnull CGImageRef)cgImage scale:(CGFloat)scale orientation:(CGImagePropertyOrientation)orientation {
    NSBitmapImageRep *imageRep;
    if (orientation != kCGImagePropertyOrientationUp) {
        // AppKit design is different from UIKit. Where CGImage based image rep does not respect to any orientation. Only data based image rep which contains the EXIF metadata can automatically detect orientation.
        // This should be nonnull, until the memory is exhausted cause `CGBitmapContextCreate` failed.
        CGImageRef rotatedCGImage = [NSImage CGImageCreateDecoded:cgImage orientation:orientation];
        imageRep = [[NSBitmapImageRep alloc] initWithCGImage:rotatedCGImage];
        CGImageRelease(rotatedCGImage);
    } else {
        imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        [self addRepresentation:imageRep];
    }
    return self;
}

- (instancetype)initWithData:(nonnull NSData *)data scale:(CGFloat)scale {
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:data];
    if (!imageRep) {
        return nil;
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        [self addRepresentation:imageRep];
    }
    return self;
}

@end


#pragma mark - JSTPixelImage

static inline JST_IMAGE *create_pixels_image_with_cgimage(CGImageRef cgimg, CGColorSpaceRef *cgColorSpace) {
    JST_IMAGE *pixels_image = NULL;
    CGSize imgSize = CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg));
    pixels_image = (JST_IMAGE *) malloc(sizeof(JST_IMAGE));
    memset(pixels_image, 0, sizeof(JST_IMAGE));
    pixels_image->width = imgSize.width;
    pixels_image->height = imgSize.height;
    JST_COLOR *pixels = (JST_COLOR *) malloc(imgSize.width * imgSize.height * sizeof(JST_COLOR));
    memset(pixels, 0, imgSize.width * imgSize.height * sizeof(JST_COLOR));
    pixels_image->pixels = pixels;
    *cgColorSpace = (CGColorSpaceRef)CFRetain(CGImageGetColorSpace(cgimg));
    CGContextRef context = CGBitmapContextCreate(
                                                 pixels,
                                                 (size_t) imgSize.width,
                                                 (size_t) imgSize.height,
                                                 8,
                                                 imgSize.width * sizeof(JST_COLOR),
                                                 *cgColorSpace,
                                                 kCGImageAlphaPremultipliedLast /* kCGImageAlphaNoneSkipLast */
                                                 );
    CGContextDrawImage(context, CGRectMake(0, 0, imgSize.width, imgSize.height), cgimg);
    CGContextRelease(context);
    return pixels_image;
}

static inline JST_IMAGE *create_pixels_image_with_nsimage(NSImage *nsimg, CGColorSpaceRef *cgColorSpace) {
    CGSize imgSize = nsimg.size;
    CGRect imgRect = CGRectMake(0, 0, imgSize.width, imgSize.height);
    return create_pixels_image_with_cgimage([nsimg CGImageForProposedRect:&imgRect context:nil hints:nil], cgColorSpace);
}

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

static inline void callback_release_data(void *info, const void *data, size_t size) {
    free((unsigned char *)data);
}

static inline CGImageRef create_cgimage_with_pixels_image(JST_IMAGE *pixels_image, CGColorSpaceRef cgColorSpace)
{
    
    int W, H;
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
    
    size_t pixels_buffer_len = (size_t) (W * H * 4);
    JST_COLOR *pixels_buffer = (JST_COLOR *) malloc(pixels_buffer_len);
    if (0 != pixels_image->orientation) {
        uint64_t big_count_offset = 0;
        JST_COLOR color_of_point;
        for (int y = 0; y < H; ++y) {
            for (int x = 0; x < W; ++x) {
                get_color_in_pixels_image_notran(pixels_image, x, y, &color_of_point);
                pixels_buffer[big_count_offset++].the_color = color_of_point.the_color;
            }
        }
    } else {
        memcpy(pixels_buffer, pixels_image->pixels, pixels_buffer_len);
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels_buffer, pixels_buffer_len, (CGDataProviderReleaseDataCallback)&callback_release_data);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wenum-conversion"
    CGImageRef img = CGImageCreate((size_t) W, (size_t) H, 8, (8 * 4), (size_t) (4 * W), cgColorSpace,
                                   kCGImageAlphaPremultipliedLast,
                                   provider, NULL, true, kCGRenderingIntentDefault);
#pragma clang diagnostic pop
    CGDataProviderRelease(provider);
    
    return img;
    
}

static inline JST_IMAGE *create_pixels_image_with_pixels_image_rect(JST_IMAGE *pixels_image_, uint8_t orien, int x1, int y1, int x2, int y2) {
    JST_IMAGE *pixels_image = NULL;
    int old_W = pixels_image_->width;
    int new_W = x2 - x1;
    int new_H = y2 - y1;
    pixels_image = (JST_IMAGE *)malloc(sizeof(JST_IMAGE));
    memset(pixels_image, 0, sizeof(JST_IMAGE));
    pixels_image->width = new_W;
    pixels_image->height = new_H;
    JST_COLOR *pixels = (JST_COLOR *)malloc(new_W * new_H * sizeof(JST_COLOR));
    memset(pixels, 0, new_W * new_H * sizeof(JST_COLOR));
    pixels_image->pixels = pixels;
    uint64_t big_count_offset = 0;
    for (int y = y1; y < y2; ++y) {
        for (int x = x1; x < x2; ++x) {
            pixels[big_count_offset++] = pixels_image_->pixels[y * old_W + x];
        }
    }
    GET_ROTATE_ROTATE3(pixels_image_->orientation, orien, pixels_image->orientation);
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

- (JSTPixelImage *)initWithInternalPointer:(JST_IMAGE *)pointer {
    self = [super init];
    if (self) {
        _pixelImage = pointer;
        _colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    }
    return self;
}

- (JSTPixelImage *)initWithCGImage:(CGImageRef)cgimage {
    self = [super init];
    if (self) {
        _pixelImage = create_pixels_image_with_cgimage(cgimage, &_colorSpace);
    }
    return self;
}

+ (JSTPixelImage *)imageWithNSImage:(NSImage *)nsimage {
    return [[JSTPixelImage alloc] initWithNSImage:nsimage];
}

- (JSTPixelImage *)initWithNSImage:(NSImage *)nsimage {
    self = [super init];
    if (self) {
        _pixelImage = create_pixels_image_with_nsimage(nsimage, &_colorSpace);
    }
    return self;
}

- (NSImage *)toNSImage {
    CGImageRef cgimg = create_cgimage_with_pixels_image(_pixelImage, _colorSpace);
    NSImage *img0 = [[NSImage alloc] initWithCGImage:cgimg scale:1.0 orientation:kCGImagePropertyOrientationUp];
    CGImageRelease(cgimg);
    return img0;
}

- (NSData *)pngRepresentation {
    CGImageRef cgimg = create_cgimage_with_pixels_image(_pixelImage, _colorSpace);
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgimg];
    [newRep setSize:CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg))];
    NSData *data = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    CGImageRelease(cgimg);
    return data;
}

- (NSData *)tiffRepresentation {
    CGImageRef cgimg = create_cgimage_with_pixels_image(_pixelImage, _colorSpace);
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgimg];
    [newRep setSize:CGSizeMake(CGImageGetWidth(cgimg), CGImageGetHeight(cgimg))];
    NSData *data = [newRep representationUsingType:NSBitmapImageFileTypeTIFF properties:@{}];
    CGImageRelease(cgimg);
    return data;
}

- (JSTPixelImage *)crop:(CGRect)rect {
    int x1 = (int) rect.origin.x;
    int y1 = (int) rect.origin.y;
    int x2 = (int) rect.origin.x + (int) rect.size.width;
    int y2 = (int) rect.origin.y + (int) rect.size.height;
    SHIFT_RECT_BY_ORIEN(x1, y1, x2, y2, _pixelImage->width, _pixelImage->height, _pixelImage->orientation);
    y2 = (y2 > _pixelImage->height) ? _pixelImage->height : y2;
    x2 = (x2 > _pixelImage->width) ? _pixelImage->width : x2;
    return [[JSTPixelImage alloc] initWithInternalPointer:create_pixels_image_with_pixels_image_rect(_pixelImage, 0, x1, y1, x2, y2)];
}

- (CGSize)size {
    int W = 0, H = 0;
    switch (_pixelImage->orientation) {
        case 1:
        case 2:
            H = _pixelImage->width;
            W = _pixelImage->height;
            break;
        default:
            W = _pixelImage->width;
            H = _pixelImage->height;
            break;
    }
    return CGSizeMake(W, H);
}

- (JST_IMAGE *)internalPointer {
    return _pixelImage;
}

- (JSTPixelColor *)getJSTColorOfPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    get_color_in_pixels_image_safe(_pixelImage, (int) point.x, (int) point.y, &color_of_point);
    return [JSTPixelColor colorWithRed:color_of_point.red green:color_of_point.green blue:color_of_point.blue alpha:color_of_point.alpha];
}

- (uint32_t)getColorOfPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    get_color_in_pixels_image_safe(_pixelImage, (int) point.x, (int) point.y, &color_of_point);
    return color_of_point.the_color;
}

- (NSString *)getColorHexOfPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    get_color_in_pixels_image_safe(_pixelImage, (int) point.x, (int) point.y, &color_of_point);
    return [[JSTPixelColor colorWithRed:color_of_point.red green:color_of_point.green blue:color_of_point.blue alpha:color_of_point.alpha] hexString];
}

- (void)setJSTColor:(JSTPixelColor *)color ofPoint:(CGPoint)point {
    JST_COLOR color_of_point;
    color_of_point.red = color.red;
    color_of_point.green = color.green;
    color_of_point.blue = color.blue;
    color_of_point.alpha = 0xff;
    set_color_in_pixels_image_safe(_pixelImage, (int) point.x, (int) point.y, &color_of_point);
}

- (void)setOrientation:(uint8_t)orientation {
    _pixelImage->orientation = orientation;
}

- (uint8_t)orientation {
    return _pixelImage->orientation;
}

- (void)dealloc {
    free_pixels_image(_pixelImage);
    CGColorSpaceRelease(_colorSpace);
#ifdef DEBUG
    NSLog(@"- [JSTPixelImage dealloc]");
#endif
}

@end
