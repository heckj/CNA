//
//  ResponseChecker.swift
//  CNA
//
//  Created by Joseph Heck on 3/15/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import Foundation
import Network
import os.log
import Socket

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let urlcheck = OSLog(subsystem: subsystem,
                                category: String(describing: ResponseChecker.self))
    // specifically to allow os_log to this category...
    // os_log("View did load!", log: OSLog.urlcheck, type: .info)
}

enum ResponseCheckerError: Error {
    case oopsy(msg: String)
    case noClosureProvided
}

public typealias SocketResponseClosure = ((_ checker: ResponseChecker, _ response: Bool) -> Void)

public class ResponseChecker: NSObject {
    var host: String
    public static let defaultPortToCheck: Int32 = 443
    public var responseClosure: SocketResponseClosure?

    public init(host: String) {
        self.host = host
    }

    public func checkSocketResponse() throws {
        guard let callback = self.responseClosure else {
            throw ResponseCheckerError.noClosureProvided
        }

        let backgroundSocketQueue = DispatchQueue(label: "socketConnectChecker")
        backgroundSocketQueue.async {
            do {
                let socket = try Socket.create(family: .inet)
                // Connect to the server
                try socket.connect(to: self.host, port: ResponseChecker.defaultPortToCheck, timeout: 1000)

                defer {
                    // Close the socket...
                    socket.close()
                }

                if !socket.isConnected {
                    callback(self, false)
                }
                os_log("connection available to %{public}@:${public}d",
                       log: OSLog.urlcheck, type: .info, self.host,
                       ResponseChecker.defaultPortToCheck)

                return callback(self, true)
            } catch let socketerror as Socket.Error {
                os_log("error connecting to %{public}@:%i : %{public}@",
                       log: OSLog.urlcheck, type: OSLogType.error,
                       self.host, // %@
                       ResponseChecker.defaultPortToCheck, // %i
                       String(describing: socketerror) // %@
                )
            } catch {
                os_log("Unknown error %{public}@",
                       log: OSLog.urlcheck, type: OSLogType.error,
                       String(describing: error))
            }
            callback(self, false)
        }
    }
}
