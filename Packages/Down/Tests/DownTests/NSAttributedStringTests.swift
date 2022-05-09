//
//  NSAttributedStringTests.swift
//  Down
//
//  Created by Rob Phillips on 6/2/16.
//  Copyright © 2016-2019 Down. All rights reserved.
//

import XCTest
@testable import Down

class NSAttributedStringTests: XCTestCase {

    func testAttributedStringBindingsWork() {
        let markdown = "## [Down](https://github.com/johnxnguyen/Down)"
        let attributedString = try? Down(markdownString: markdown).toAttributedString()
        XCTAssertNotNil(attributedString)
        XCTAssertTrue(attributedString!.string == "Down\n")
    }

    func testInstantiation() {
        let attributedString = try? NSAttributedString(htmlString: "<html><body><p>Oh Hai</p></body></html>")
        XCTAssertNotNil(attributedString)
        XCTAssertTrue(attributedString!.string == "Oh Hai\n")
    }

}
