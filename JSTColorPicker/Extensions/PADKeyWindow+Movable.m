//
//  PADKeyWindow+Movable.m
//  JSTColorPickerSparkle
//
//  Created by Darwin on 2022/4/25.
//  Copyright © 2022 JST. All rights reserved.
//

#import "PADKeyWindow+Movable.h"

@implementation PADKeyWindow (Movable)

- (void)mouseDown:(NSEvent *)event {
    [self.sheetParent performWindowDragWithEvent:event];
}

@end
