//
//  Down+Ext.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/21/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import Down

private struct JSTMiniColorCollection: ColorCollection {
    
    var heading1: DownColor
    var heading2: DownColor
    var heading3: DownColor
    var heading4: DownColor
    var heading5: DownColor
    var heading6: DownColor
    var body: DownColor
    var code: DownColor
    var link: DownColor
    var quote: DownColor
    var quoteStripe: DownColor
    var thematicBreak: DownColor
    var listItemPrefix: DownColor
    var codeBlockBackground: DownColor
    
    init(
        heading1: DownColor = .labelColor,
        heading2: DownColor = .labelColor,
        heading3: DownColor = .labelColor,
        heading4: DownColor = .labelColor,
        heading5: DownColor = .labelColor,
        heading6: DownColor = .labelColor,
        body: DownColor = .labelColor,
        code: DownColor = .labelColor,
        link: DownColor = .linkColor,
        quote: DownColor = .secondaryLabelColor,
        quoteStripe: DownColor = .secondaryLabelColor,
        thematicBreak: DownColor = .init(white: 0.9, alpha: 1),
        listItemPrefix: DownColor = .tertiaryLabelColor,
        codeBlockBackground: DownColor = .init(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
    ) {
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.body = body
        self.code = code
        self.link = link
        self.quote = quote
        self.quoteStripe = quoteStripe
        self.thematicBreak = thematicBreak
        self.listItemPrefix = listItemPrefix
        self.codeBlockBackground = codeBlockBackground
    }
}

private struct JSTMiniParagraphStyleCollection: ParagraphStyleCollection {
    
    var heading1: NSParagraphStyle
    var heading2: NSParagraphStyle
    var heading3: NSParagraphStyle
    var heading4: NSParagraphStyle
    var heading5: NSParagraphStyle
    var heading6: NSParagraphStyle
    var body: NSParagraphStyle
    var code: NSParagraphStyle
    
    init() {
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacing = 4
        
        let bodyStyle = NSMutableParagraphStyle()
        // use default paragraph style
        
        let codeStyle = NSMutableParagraphStyle()
        codeStyle.paragraphSpacingBefore = 4
        codeStyle.paragraphSpacing = 4
        
        heading1 = headingStyle
        heading2 = headingStyle
        heading3 = headingStyle
        heading4 = headingStyle
        heading5 = headingStyle
        heading6 = headingStyle
        body = bodyStyle
        code = codeStyle
    }
}

private struct JSTMiniFontCollection: FontCollection {
    
    var heading1: DownFont
    var heading2: DownFont
    var heading3: DownFont
    var heading4: DownFont
    var heading5: DownFont
    var heading6: DownFont
    var body: DownFont
    var code: DownFont
    var listItemPrefix: DownFont
    
    init(
        heading1: DownFont = .boldSystemFont(ofSize: 23),
        heading2: DownFont = .boldSystemFont(ofSize: 20),
        heading3: DownFont = .boldSystemFont(ofSize: 17),
        heading4: DownFont = .boldSystemFont(ofSize: 15),
        heading5: DownFont = .boldSystemFont(ofSize: 13),
        heading6: DownFont = .boldSystemFont(ofSize: 11),
        body: DownFont = .systemFont(ofSize: 11),
        code: DownFont = DownFont(name: "menlo", size: 11) ?? .systemFont(ofSize: 11),
        listItemPrefix: DownFont = DownFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    ) {
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.body = body
        self.code = code
        self.listItemPrefix = listItemPrefix
    }
}

extension String {
    var markdownAttributed: NSAttributedString {
        var configuration = DownStylerConfiguration()
        configuration.fonts = JSTMiniFontCollection()
        configuration.colors = JSTMiniColorCollection()
        configuration.paragraphStyles = JSTMiniParagraphStyleCollection()
        return try! Down(markdownString: self).toAttributedString(.default, styler: DownStyler(configuration: configuration))
    }
}
