//
//  SwiftyPing.swift
//  SwiftyPing
//
//  Created by Sami Yrjänheikki on 6.8.2018.
//  Copyright © 2018 Sami Yrjänheikki. All rights reserved.
//  Copyright © 2019 Joseph Heck. All rights reserved.
//
// MIT Licensed, per https://github.com/heckj/SwiftyPing <- https://github.com/imas145/SwiftyPing

import Darwin
import Foundation

public typealias PingResponseClosure = (( _ ping: SwiftyPing, _ response: PingResponse) -> Void)
public typealias ErrorClosure = ((_ ping: SwiftyPing, _ error: NSError) -> Void)

// MARK: SwiftyPing
// swiftlint:disable:next type_body_length
public class SwiftyPing: NSObject {
    var host: String
    // swiftlint:disable:next identifier_name
    var ip: String
    var configuration: PingConfiguration

    public var responseClosure: PingResponseClosure?
    public var errorClosure: ErrorClosure?

    var identifier: UInt32

    private var hasScheduledNextPing = false
    private var ipv4address: Data?
    private var socket: CFSocket?
    private var socketSource: CFRunLoopSource?

    private var isPinging = false
    private var currentSequenceNumber: UInt64 = 0
    private var currentStartDate: Date?

    private var timeoutBlock:(() -> Void)?

    private var currentQueue: DispatchQueue?

    private let serial = DispatchQueue(label: "ping serial",
                                       qos: .userInteractive,
                                       attributes: [],
                                       autoreleaseFrequency: .workItem,
                                       target: nil)

    func socketCallback(socket: CFSocket,
                        type: CFSocketCallBackType,
                        address: CFData,
                        data: UnsafeRawPointer,
                        info: UnsafeMutableRawPointer) {
        var info = info
        let ping = withUnsafePointer(to: &info) { temp in
            return unsafeBitCast(temp, to: SwiftyPing.self)
        }

        if (type as CFSocketCallBackType) == CFSocketCallBackType.dataCallBack {
            let fData = data.assumingMemoryBound(to: UInt8.self)
            let bytes = UnsafeBufferPointer<UInt8>(start: fData, count: MemoryLayout<UInt8>.size)
            let cfdata = Data(buffer: bytes)
            ping.socket(socket: socket, didReadData: cfdata)
        }
    }

    class func getIPv4AddressFromHost(host: String) -> (data: Data?, error: NSError?) {
        var streamError = CFStreamError()
        let cfhost = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
        let status = CFHostStartInfoResolution(cfhost, .addresses, &streamError)

        var data: Data?
        if !status {
            if Int32(streamError.domain) == kCFStreamErrorDomainNetDB {
                return (nil, NSError(domain: kCFErrorDomainCFNetwork as String,
                                     code: Int(CFNetworkErrors.cfHostErrorUnknown.rawValue),
                                     userInfo: [kCFGetAddrInfoFailureKey as String: "error in address lookup"]))
            } else {
                return (nil,
                        NSError(domain: kCFErrorDomainCFNetwork as String,
                                code: Int(CFNetworkErrors.cfHostErrorUnknown.rawValue), userInfo: nil))
            }
        } else {
            var success: DarwinBoolean = false
            guard let addresses = CFHostGetAddressing(cfhost, &success)?.takeUnretainedValue() as? [Data] else {
                return (nil, NSError(domain: kCFErrorDomainCFNetwork as String,
                                     code: Int(CFNetworkErrors.cfHostErrorHostNotFound.rawValue),
                                     // swiftlint:disable:next line_length
                                     userInfo: [NSLocalizedDescriptionKey: "failed to retrieve the addresses from given host"]))
            }

            for address in addresses {
                let addrin = address.socketAddress
                if address.count >= MemoryLayout<sockaddr>.size && addrin.sa_family == UInt8(AF_INET) {
                    data = address
                    break
                }
            }

            // swiftlint:disable:next empty_count
            if data?.count == 0 || data == nil {
                return (nil, NSError(domain: kCFErrorDomainCFNetwork as String,
                                     code: Int(CFNetworkErrors.cfHostErrorHostNotFound.rawValue),
                                     userInfo: nil))
            }
        }

        return (data, nil)
    }

    init(host: String, ipv4Address: Data, configuration: PingConfiguration, queue: DispatchQueue) {
        self.host = host
        self.ipv4address = ipv4Address
        self.configuration = configuration
        self.identifier = UInt32(arc4random_uniform(UInt32(UInt16.max)))
        self.currentQueue = queue

        let socketAddress = ipv4Address.socketAddressInternet
        self.ip = String(cString: inet_ntoa(socketAddress.sin_addr), encoding: String.Encoding.ascii) ?? ""

        super.init()

        var context = CFSocketContext(version: 0,
                                      info: Unmanaged.passRetained(self).toOpaque(),
                                      retain: nil,
                                      release: nil,
                                      copyDescription: nil)

        self.socket = CFSocketCreate(kCFAllocatorDefault,
                                     AF_INET,
                                     SOCK_DGRAM,
                                     IPPROTO_ICMP,
                                     CFSocketCallBackType.dataCallBack.rawValue, { socket, type, _, data, info in
                                        // _ was "address", but unused
            guard let socket = socket, let info = info else { return }
            let ping: SwiftyPing = Unmanaged.fromOpaque(info).takeUnretainedValue()
            if (type as CFSocketCallBackType) == CFSocketCallBackType.dataCallBack {
                let fData = data?.assumingMemoryBound(to: UInt8.self)
                let bytes = UnsafeBufferPointer<UInt8>(start: fData, count: MemoryLayout<UInt8>.size)
                let cfdata = Data(buffer: bytes)
                ping.socket(socket: socket, didReadData: cfdata)
            }
        }, &context)

        socketSource = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), socketSource, .commonModes)
    }

    convenience init(ipv4Address: String, config configuration: PingConfiguration, queue: DispatchQueue) {
        var socketAddress = sockaddr_in()
        memset(&socketAddress, 0, MemoryLayout<sockaddr_in>.size)

        socketAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        socketAddress.sin_family = UInt8(AF_INET)
        socketAddress.sin_port = 0
        socketAddress.sin_addr.s_addr = inet_addr(ipv4Address.cString(using: String.Encoding.utf8))
        let data = NSData(bytes: &socketAddress, length: MemoryLayout<sockaddr_in>.size)

        self.init(host: ipv4Address, ipv4Address: data as Data, configuration: configuration, queue: queue)
    }
    convenience init?(host: String, configuration: PingConfiguration, queue: DispatchQueue) {
        let result = SwiftyPing.getIPv4AddressFromHost(host: host)
        if let address = result.data {
            self.init(host: host, ipv4Address: address, configuration: configuration, queue: queue)
        } else {
            return nil
        }
    }

    deinit {
        CFRunLoopSourceInvalidate(socketSource)
        socketSource = nil
        socket = nil
    }

    public func start() {
        serial.sync {
            if !self.isPinging {
                self.isPinging = true
                self.currentSequenceNumber = 0
                self.currentStartDate = nil
            }
        }
        currentQueue?.async {
            self.sendPing()
        }
    }

    public func stop() {
        serial.sync {
            self.isPinging = false
            self.currentSequenceNumber = 0
            self.currentStartDate = nil
            self.timeoutBlock = nil
        }
    }

    func scheduleNextPing() {
        serial.sync {
            // stop attempts to schedule another ping if the sequenceCount has gone above the limit
            if self.configuration.pingCountLimit > 0 &&
                self.currentSequenceNumber > self.configuration.pingCountLimit {
                return
            }

            if self.hasScheduledNextPing {
                return
            }

            self.hasScheduledNextPing = true
            self.timeoutBlock = nil
            self.currentQueue?.asyncAfter(deadline: .now() + self.configuration.pingInterval, execute: {
                self.hasScheduledNextPing = false
                self.sendPing()
            })
        }
    }

    // process the raw socket callback data, sorting out the data fields and extracting
    // the details.
    func socket(socket: CFSocket, didReadData data: Data?) {
        var ipHeaderData: NSData?
        var ipData: NSData?
        var icmpHeaderData: NSData?
        var icmpData: NSData?

        let extractIPAddressBlock: () -> String? = {
            if ipHeaderData == nil {
                return nil
            }
            guard var bytes = ipHeaderData?.bytes else { return nil }
            let ipHeader: IPHeader = withUnsafePointer(to: &bytes) { temp in
                return unsafeBitCast(temp, to: IPHeader.self)
            }

            let sourceAddr = ipHeader.sourceAddress

            return "\(sourceAddr[0]).\(sourceAddr[1]).\(sourceAddr[2]).\(sourceAddr[3])"
        }
        guard let data = data else { return }
        if !ICMPExtractResponseFromData(data: data as NSData,
                                        ipHeaderData: &ipHeaderData,
                                        ipData: &ipData,
                                        icmpHeaderData: &icmpHeaderData,
                                        icmpData: &icmpData) {
            if ipHeaderData != nil, ip == extractIPAddressBlock() {
                return
            }
        }
        guard let currentStartDate = currentStartDate else { return }
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotDecodeRawData, userInfo: nil)
        let response = PingResponse(id: identifier,
                                    ipAddress: nil,
                                    sequenceNumber: Int64(currentSequenceNumber),
                                    duration: Date().timeIntervalSince(currentStartDate),
                                    error: error)
        responseClosure?(self, response)

        return scheduleNextPing()
    }

    // swiftlint:disable:next function_body_length
    func sendPing() {
        if !self.isPinging {
            return
        }

        self.currentSequenceNumber += 1
        self.currentStartDate = Date()

        guard let icmpPackage = ICMPPackageCreate(identifier: UInt16(identifier),
                                                  sequenceNumber: UInt16(currentSequenceNumber),
                                                  payloadSize: UInt32(configuration.payloadSize)),
            let socket = socket,
            let address = ipv4address
            else { return }
        let socketError = CFSocketSendData(socket,
                                           address as CFData,
                                           icmpPackage as CFData,
                                           configuration.timeoutInterval)

        switch socketError {
        case .error:
            let error = NSError(domain: NSURLErrorDomain,
                                code: NSURLErrorCannotFindHost,
                                userInfo: [:])
            let response = PingResponse(id: self.identifier,
                                        ipAddress: nil,
                                        sequenceNumber: Int64(currentSequenceNumber),
                                        duration: Date().timeIntervalSince(currentStartDate!),
                                        error: error)
            responseClosure?(self, response)

            return self.scheduleNextPing()
        case .timeout:
            let error = NSError(domain: NSURLErrorDomain,
                                code: NSURLErrorTimedOut,
                                userInfo: [:])
            let response = PingResponse(id: self.identifier,
                                        ipAddress: nil,
                                        sequenceNumber: Int64(currentSequenceNumber),
                                        duration: Date().timeIntervalSince(currentStartDate!),
                                        error: error)
            responseClosure?(self, response)

            return self.scheduleNextPing()
        default: break
        }

        let sequenceNumber = currentSequenceNumber
        timeoutBlock = { () -> Void in
            if sequenceNumber != self.currentSequenceNumber {
                return
            }

            self.timeoutBlock = nil
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [:])
            let response = PingResponse(id: self.identifier,
                                        ipAddress: nil,
                                        sequenceNumber: Int64(self.currentSequenceNumber),
                                        duration: Date().timeIntervalSince(self.currentStartDate!),
                                        error: error)
            self.responseClosure?(self, response)
            self.scheduleNextPing()
        }
    }
}

// Helper classes

public class PingResponse: NSObject {
    public var identifier: UInt32
    public var ipAddress: String?
    public var sequenceNumber: Int64
    public var duration: TimeInterval
    public var error: NSError?

    public init(id: UInt32,
                ipAddress addr: String?,
                sequenceNumber number: Int64,
                duration dur: TimeInterval,
                error err: NSError?) {
        identifier = id
        ipAddress = addr
        sequenceNumber = number
        duration = dur
        error = err
    }
}

public struct PingConfiguration {
    let pingInterval: TimeInterval
    let timeoutInterval: TimeInterval
    let payloadSize: UInt64
    let pingCountLimit: UInt64

    public static let pingInterval: TimeInterval = 1
    public static let pingTimeout: TimeInterval = 2
    public static let pingDataSize: UInt64 = 64
    public static let pingLimit: UInt64 = 0

    public init(interval: TimeInterval = pingInterval,
                timeout: TimeInterval = pingTimeout,
                payload: UInt64 = pingDataSize,
                limit: UInt64 = pingLimit) {
        pingInterval = interval
        timeoutInterval = timeout
        payloadSize = payload
        pingCountLimit = limit
    }
    public init(interval: TimeInterval) {
        self.init(interval: interval,
                  timeout: PingConfiguration.pingTimeout)
    }
    public init(interval: TimeInterval, count: UInt64) {
        self.init(interval: interval,
                  timeout: PingConfiguration.pingTimeout,
                  payload: PingConfiguration.pingDataSize,
                  limit: count)
    }
    public init(interval: TimeInterval, with timeout: TimeInterval) {
        self.init(interval: interval,
                  timeout: timeout,
                  payload: PingConfiguration.pingDataSize,
                  limit: PingConfiguration.pingLimit)
    }
}

// MARK: ICMP

struct IPHeader {
    var versionAndHeaderLength: UInt8
    var differentiatedServices: UInt8
    var totalLength: UInt16
    var identification: UInt16
    var flagsAndFragmentOffset: UInt16
    var timeToLive: UInt8
    var `protocol`: UInt8
    var headerChecksum: UInt16
    var sourceAddress: [UInt8]
    var destinationAddress: [UInt8]
}

struct ICMPHeader {
    var type: UInt8      /* type of message*/
    var code: UInt8      /* type sub code */
    var checkSum: UInt16 /* ones complement cksum of struct */
    var identifier: UInt16
    var sequenceNumber: UInt16
    var data: timeval
}

// ICMP type and code combinations:
// reference:
// https://www.ibm.com/support/knowledgecenter/en/SS42VS_7.3.1/com.ibm.qradar.doc/c_DefAppCfg_guide_ICMP_intro.html

enum ICMPType: UInt8 {
    case echoReply = 0
    case echoRequest = 8
    case destinationUnreachable = 3
    case sourceQuench = 4
    case redirect = 5
    case routerAdvertisement = 9
    case routerSelection = 10
    case timeExceeded = 11
    case parameterProblem = 12
    case timestamp = 13
    case timestampReply = 14
    case informationRequest = 15
    case informationReply = 16
    case addressMaskRequest = 17
    case addressMaskReply = 18
    case traceRoute = 30
}

// subtype from ICMPType 3: destinationUnreachable
enum ICMPDestinationUnreachable: UInt8 {
    case netUnreachable = 0
    case hostUnreachable = 1
    case protocolUnreachable = 2
    case portUnreachable = 3
    case fragmentationNeeded = 4
    case sourceRouteFailed = 5
    case destinationNetworkUnknown = 6
    case destinationHostUnknown = 7
    case sourceHostIsolated = 8
    case communicationToNetworkAdminProhibited = 9
    case communicationToHostAdminProhibited = 10
    // swiftlint:disable:next identifier_name
    case destinationNetworkUnreachableForTypeOfService = 11
    // swiftlint:disable:next identifier_name
    case destinationHostUnreachableForTypeOfService = 12
    case communicationAdminProhibited = 13
    case hostPrecedenceViolation = 14
    case precedenceCuttoffInEffect = 15
}
// subtype from ICMPType 5: redirect
enum ICMPRedirect: UInt8 {
    case redirectDatagramForNetwork = 0
    case redirectDatagramForHost = 1
    // swiftlint:disable:next identifier_name
    case redirectDatagramForTypeOfServiceAndNetwork = 2
    case redirectDatagramForTypeOfServiceAndHost = 3
}
// subtype from ICMPType 11: timeExceeded
enum ICMPTimeExceeded: UInt8 {
    case timeToLiveExceededInTransit = 0
    case fragmentReassemblyTimeExceeded = 1
}
// subtype from ICMPType 12: parameterProblem
enum ICMPParameterProblem: UInt8 {
    case pointerIndicatesError = 0
    case missingRequiredOption = 1
    case badLength = 2
}

// static inline uint16_t in_cksum(const void *buffer, size_t bufferLen)

@inline(__always)
func checkSum(buffer: UnsafeMutableRawPointer, bufLen: Int) -> UInt16 {
    var bufLen = bufLen
    var checksum: UInt32 = 0
    var buf = buffer.assumingMemoryBound(to: UInt16.self)

    while bufLen > 1 {
        checksum += UInt32(buf.pointee)
        buf = buf.successor()
        bufLen -= MemoryLayout<UInt16>.size
    }

    if bufLen == 1 {
        checksum += UInt32(UnsafeMutablePointer<UInt16>(buf).pointee)
    }
    checksum = (checksum >> 16) + (checksum & 0xFFFF)
    checksum += checksum >> 16
    return ~UInt16(checksum)
}

// package creation

func ICMPPackageCreate(identifier: UInt16, sequenceNumber: UInt16, payloadSize: UInt32) -> NSData? {
//    let packageDebug = false  // triggers print statements below

    var icmpType = ICMPType.echoRequest.rawValue
    var icmpCode: UInt8 = 0
    var icmpChecksum: UInt16 = 0
    var icmpIdentifier = identifier
    var icmpSequence = sequenceNumber

    // swiftlint:disable:next line_length
    let packet = "baadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaadbaad"
    guard let packetData = packet.data(using: .utf8) else { return nil }
    var payload = NSData(data: packetData)
    payload = payload.subdata(with: NSRange(location: 0, length: Int(payloadSize))) as NSData
    guard let package = NSMutableData(capacity: MemoryLayout<ICMPHeader>.size + payload.length) else { return nil }
    package.replaceBytes(in: NSRange(location: 0, length: 1), withBytes: &icmpType)
    package.replaceBytes(in: NSRange(location: 1, length: 1), withBytes: &icmpCode)
    package.replaceBytes(in: NSRange(location: 2, length: 2), withBytes: &icmpChecksum)
    package.replaceBytes(in: NSRange(location: 4, length: 2), withBytes: &icmpIdentifier)
    package.replaceBytes(in: NSRange(location: 6, length: 2), withBytes: &icmpSequence)
    package.replaceBytes(in: NSRange(location: 8, length: payload.length), withBytes: payload.bytes)

    let bytes = package.mutableBytes
    icmpChecksum = checkSum(buffer: bytes, bufLen: package.length)
    package.replaceBytes(in: NSRange(location: 2, length: 2), withBytes: &icmpChecksum)
//    if packageDebug { print("ping package: \(package)") }
    return package
}

@inline(__always)
func ICMPExtractResponseFromData(data: NSData,
                                 ipHeaderData: AutoreleasingUnsafeMutablePointer<NSData?>,
                                 ipData: AutoreleasingUnsafeMutablePointer<NSData?>,
                                 icmpHeaderData: AutoreleasingUnsafeMutablePointer<NSData?>,
                                 icmpData: AutoreleasingUnsafeMutablePointer<NSData?>) -> Bool {
    guard let buffer = data.mutableCopy() as? NSMutableData else { return false }

    if buffer.length < (MemoryLayout<IPHeader>.size+MemoryLayout<ICMPHeader>.size) {
        return false
    }

    var mutableBytes = buffer.mutableBytes

    let ipHeader = withUnsafePointer(to: &mutableBytes) { temp in
        return unsafeBitCast(temp, to: IPHeader.self)
    }

    // IPv4 and ICMP
    guard ipHeader.versionAndHeaderLength & 0xF0 == 0x40, ipHeader.protocol == 1 else { return false }

    let ipHeaderLength = (ipHeader.versionAndHeaderLength & 0x0F) * UInt8(MemoryLayout<UInt32>.size)
    // swiftlint:disable:next legacy_constructor
    let range = NSMakeRange(0, MemoryLayout<IPHeader>.size)
    ipHeaderData.pointee = buffer.subdata(with: range) as NSData?

    if buffer.length >= MemoryLayout<IPHeader>.size + Int(ipHeaderLength) {
        // swiftlint:disable:next legacy_constructor
        ipData.pointee = buffer.subdata(with: NSMakeRange(MemoryLayout<IPHeader>.size, Int(ipHeaderLength))) as NSData?
    }

    if buffer.length < Int(ipHeaderLength) + MemoryLayout<ICMPHeader>.size {
        return false
    }

    let icmpHeaderOffset = size_t(ipHeaderLength)

    var headerBuffer = mutableBytes.assumingMemoryBound(to: UInt8.self) + icmpHeaderOffset

    var icmpHeader = withUnsafePointer(to: &headerBuffer) { temp in
        return unsafeBitCast(temp, to: ICMPHeader.self)
    }

    let receivedChecksum = icmpHeader.checkSum
    let calculatedChecksum = checkSum(buffer: &icmpHeader, bufLen: buffer.length - icmpHeaderOffset)
    icmpHeader.checkSum = receivedChecksum

    if receivedChecksum != calculatedChecksum {
        print("invalid ICMP header. Checksums did not match")
        return false
    }

    // swiftlint:disable:next legacy_constructor
    let icmpDataRange = NSMakeRange(icmpHeaderOffset + MemoryLayout<ICMPHeader>.size,
                                    buffer.length - (icmpHeaderOffset + MemoryLayout<ICMPHeader>.size))
    // swiftlint:disable:next legacy_constructor
    icmpHeaderData.pointee = buffer.subdata(with: NSMakeRange(icmpHeaderOffset,
                                                              MemoryLayout<ICMPHeader>.size)) as NSData?
    icmpData.pointee = buffer.subdata(with: icmpDataRange) as NSData?

    return true
}

// swiftlint:disable:next extension_access_modifier
extension Data {
    public var socketAddress: sockaddr {
        return self.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> sockaddr in
            let raw = UnsafeRawPointer(pointer)
            let address = raw.assumingMemoryBound(to: sockaddr.self).pointee
            return address
        }
    }
    public var socketAddressInternet: sockaddr_in {
        return self.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> sockaddr_in in
            let raw = UnsafeRawPointer(pointer)
            let address = raw.assumingMemoryBound(to: sockaddr_in.self).pointee
            return address
        }
    }
    // swiftlint:disable:next file_length
}
