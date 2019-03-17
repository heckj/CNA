# CNA

Coffeeshop Network Advisor

Review and advise on the network connectivity status for my favorite local coffee shop

## Project Setup

get the dependencies established for the project:

    git submodule init
    git submodule update

## Command Line Building

view all the settings:

    xcodebuild -showBuildSettings

view the schemes and targets:

    xcodebuild -list

do a build:

    xcodebuild -scheme CNA -sdk iphoneos12.1 -configuration Debug
    xcodebuild -scheme CNA -sdk iphoneos12.1 -configuration Release

other building:

    xcodebuild -scheme Charts -sdk iphoneos12.1
    xcodebuild -scheme Socket-Package -sdk iphoneos12.1
    xcodebuild -scheme SwiftyPing-Package -sdk iphoneos12.1
    xcodebuild -scheme CNA -sdk iphoneos12.1

testing subprojects

    xcodebuild -scheme ChartsTests -sdk iphoneos12.1
    xcodebuild -scheme SocketPackageTests -sdk iphoneos12.1

## Developer Reading

App Extensions (making a "Today" Widget)

- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/index.html#//apple_ref/doc/uid/TP40014214-CH20-SW3

FontAwesome

- notes on using FontAwesome (4/5) in an IOS project (outside of SVG's in assets)
- https://medium.com/@umairhassanbaig/ios-how-to-use-font-awesome-in-xcode-project-b8ef255973a3
- cheatsheet: https://origin.fontawesome.com/cheatsheet

ICMP Ping with Swift

- https://github.com/imas145/SwiftyPing

Network.framework (IOS12+ only...)

- establishing and monitoring network paths (the new stuff)
- https://developer.apple.com/documentation/network/nwpathmonitor
- https://developer.apple.com/videos/play/wwdc2018/715/
- https://devstreaming-cdn.apple.com/videos/wwdc/   2018/715o2fzpdzzzf5f0/715/715_introducing_networkframework_a_modern_alternative_to_sockets.pdf?dl=1
- https://www.hackingwithswift.com/example-code/networking/how-to-check-for-internet-connectivity-using-nwpathmonitor

URLSessionTaskMetrics

- for getting metrics from URLSession requests
- https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics

Connectivity

- https://medium.com/@rwbutler/nwpathmonitor-the-new-reachability-de101a5a8835
- https://github.com/rwbutler/Connectivity

Charting

- https://github.com/annalizhaz/ChartsForSwiftBasic
- https://github.com/danielgindi/Charts

