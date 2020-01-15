#ifndef JST_COLOR_h
#define JST_COLOR_h

#import <stdint.h>

typedef union JST_COLOR JST_COLOR;

/* Color Struct */
union JST_COLOR {
    uint32_t the_color; /* the_color is name of color value */
    struct { /* RGB struct */
        uint8_t blue;
        uint8_t green;
        uint8_t red;
        uint8_t alpha;
    };
};

#endif /* JST_COLOR_h */

