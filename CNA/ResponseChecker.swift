//
//  ResponseChecker.swift
//  CNA
//
//  Created by Joseph Heck on 3/15/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import Foundation
import Socket

enum ResponseCheckerError: Error {
    case oopsy(msg: String)
    case noClosureProvided
}

public typealias SocketResponseClosure = (( _ checker: ResponseChecker, _ response: Bool) -> Void)

public class ResponseChecker: NSObject {
    var host: String
    public var responseClosure: SocketResponseClosure?

    public static let defaultPortToCheck: Int32 = 443

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
//                print("\nConnected to host: \(self.host):\(ResponseChecker.defaultPortToCheck)")
//                print("\tSocket signature: \(socket.signature!.description)\n")

                return callback(self, true)
            } catch let error as Socket.Error {
                print("Error while creating and connecting to socket: code \(error.errorCode) :",
                      error)
            } catch {
                print("Unknown error: \(error)")
            }
            callback(self, false)
        }
    }
}
