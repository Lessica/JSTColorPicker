#ifndef JST_IMAGE_h
#define JST_IMAGE_h

#import <stdint.h>
#import "JST_BOOL.h"
#import "JST_COLOR.h"
#import "JST_ORIENTATION.h"

struct JST_IMAGE {
    JST_ORIENTATION orientation;
    int width;
    int height;
    JST_COLOR *pixels;
    JST_BOOL is_destroyed;
};

#endif /* JST_IMAGE_h */

