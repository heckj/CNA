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

    xcodebuild -scheme CNA -sdk iphoneos13.2 -configuration Debug
    xcodebuild -scheme CNA -sdk iphoneos13.2 -configuration Release

run the tests:

    xcodebuild clean test -scheme CNA -sdk iphoneos13.2 -destination 'platform=iOS Simulator,OS=13.3,name=iPhone 8'

## Developer Reading

App Extensions (making a "Today" Widget)

- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/index.html#//apple_ref/doc/uid/TP40014214-CH20-SW3

Charting

- https://github.com/annalizhaz/ChartsForSwiftBasic
- https://github.com/danielgindi/Charts

