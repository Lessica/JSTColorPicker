//
//  LNPropertyListDatePickerPanel.h
//  LNPropertyListEditor
//
//  Created by Leo Natan (Wix) on 9/11/19.
//  Copyright © 2019 Leo Natan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LNPropertyListDatePickerPanelBackgroundView : NSView

@property (nonatomic, weak) NSView* textDatePicker;
@property (nonatomic, weak) NSView* visualDatePicker;

@end

@class LNPropertyListDatePickerPanel;

@protocol LNPropertyListDatePickerPanelDelegate <NSObject>

- (void)propertyListDatePickerPanelDidClose:(LNPropertyListDatePickerPanel*)panel;

@end
 
@interface LNPropertyListDatePickerPanel : NSPanel

@property (nonatomic, weak) id<LNPropertyListDatePickerPanelDelegate> datePickerPanelDelegate;

@end
