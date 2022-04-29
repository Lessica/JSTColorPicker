//
//  EditableTextColorTransformer.m
//  JSTColorPicker
//
//  Created by Darwin on 4/28/22.
//  Copyright © 2022 JST. All rights reserved.
//

#import "EditableTextColorTransformer.h"
#import <AppKit/NSColor.h>

@implementation EditableTextColorTransformer

+ (Class)transformedValueClass {
    return [NSColor class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (NSColor *)transformedValue:(NSNumber *)isEditable {
    if ([isEditable boolValue]) {
        return [NSColor controlTextColor];
    } else {
        return [NSColor disabledControlTextColor];
    }
}

@end
