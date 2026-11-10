// swift-tools-version: 5.9
//
//  Package.swift
//  snaply_agent
//
//  Created by Gevorg Karapetyan on 11/10/26.
//  Copyright © 2026 iFixgroup. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "snaply_agent",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "snaply-agent", targets: ["snaply_agent"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/Mobile-LLC/SnaplyAgent-SDK-iOS", from: "2.48.0")
    ],
    targets: [
        .target(
            name: "snaply_agent",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "SnaplyAgent", package: "SnaplyAgent-SDK-iOS")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
