#ifndef JST_POS_h
#define JST_POS_h

#import <stdint.h>
#import "JST_COLOR.h"

typedef struct JST_POS JST_POS;

/* Pos Struct */
struct JST_POS {
    int32_t x;
    int32_t y;
    union {
        uint32_t the_color; /* the_color is name of color value */
        struct { /* RGB struct */
            uint8_t blue;
            uint8_t green;
            uint8_t red;
            uint8_t alpha;
        };
    };
    int8_t sim;
    JST_COLOR color_offset;
};

#endif /* JST_POS_h */
