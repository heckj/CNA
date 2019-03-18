# CNA

Coffeeshop Network Advisor

Review and advise on the network connectivity status for my favorite local coffee shop

## Project Setup

get the dependencies established for the project:

    git submodule init
    git submodule update

build uses two secondary tools (optional really): swiftformat and swiftlint

    brew install swiftlint
    brew install swiftformat

## Command Line Building

view all the settings:

    xcodebuild -showBuildSettings

view the schemes and targets:

    xcodebuild -list

view destinations:

    xcodebuild -scheme CNA -showdestinations

do a build:

    xcodebuild -scheme CNA -sdk iphoneos12.1 -configuration Debug
    xcodebuild -scheme CNA -sdk iphoneos12.1 -configuration Release

run the tests:

    xcodebuild clean test -scheme CNA -sdk iphoneos12.1 -destination 'platform=iOS Simulator,OS=12.1,name=iPhone 5s' | xcpretty --color

building just the subprojects:

    xcodebuild -scheme Charts -sdk iphoneos12.1
    xcodebuild -scheme Socket-Package -sdk iphoneos12.1
    xcodebuild -scheme SwiftyPing-Package -sdk iphoneos12.1

testing subprojects:

    xcodebuild -scheme ChartsTests -sdk iphoneos12.1
    xcodebuild -scheme SocketPackageTests -sdk iphoneos12.1

## Developer Reading

App Extensions (making a "Today" Widget)

- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/index.html#//apple_ref/doc/uid/TP40014214-CH20-SW3

Charting

- https://github.com/annalizhaz/ChartsForSwiftBasic
- https://github.com/danielgindi/Charts

