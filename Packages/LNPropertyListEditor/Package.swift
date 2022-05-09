// swift-tools-version:5.3

import PackageDescription

let package = Package(
	name: "LNPropertyListEditor",
	defaultLocalization: "en",
	platforms: [
		.macOS(.v10_13)
	],
	products: [
		.library(
			name: "LNPropertyListEditor",
			type: .dynamic,
			targets: ["LNPropertyListEditor"]),
	],
	dependencies: [],
	targets: [
		.target(
			name: "LNPropertyListEditor",
			path: "LNPropertyListEditor",
			exclude: [
				"LNPropertyListEditor/Info.plist"
			],
			resources: [
				.process("LNPropertyListEditor/Assets.xcassets"),
                .process("LNPropertyListEditor/Implementation/LNPropertyListEditorOutline.xib", localization: .base)
			],
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("."),
				.headerSearchPath("LNPropertyListEditor"),
			]),
	]
)
