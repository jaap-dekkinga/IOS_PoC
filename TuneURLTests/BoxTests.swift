//
//  BoxTests.swift
//  TuneURLTests
//
//  Created by Aleksandar Mihailovski on 11/13/18.
//  Copyright © 2018-2019 TuneURL Inc. All rights reserved.
//


import XCTest
@testable import TuneURL


class BoxTests: XCTestCase {

	override func setUp() {}
	override func tearDown() {}

	func testStringBox()
	{
		let myString = "What"
		let stringBox = Box(myString)
		XCTAssertEqual(myString, stringBox.value)
		XCTAssertEqual(Box(myString), stringBox)
	}

	func testStringBoxAsNSacheKey()
	{
		let cache = NSCache<Box<URL>, NSObject>()
		let data = NSObject()
		let url = URL(string: "https://www.google.com")!

		cache.setObject(data, forKey: Box(url))
		let getData = cache.object(forKey: Box(url))!
		XCTAssertEqual(data, getData)
	}

}
