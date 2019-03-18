//
//  NetworkAnalyzer.swift
//  CNA
//
//  Created by Joseph Heck on 3/18/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import Foundation
import Network
import os.log

// WHEN DATA CHANGES:
// - public callback for the NWPathMonitor triggering a changes
// - callback for each URL being validated
// Sort of an open question on which to use: a delegate pattern or a callback pattern
// Delegate matches the "willXXX"/"didXXX" operations
// callback can be specific to each individual URL

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    static let netcheck = OSLog(subsystem: subsystem,
                                category: String(describing: NetworkAnalyzer.self))
    // specifically to allow os_log to this category...
    // os_log("View did load!", log: OSLog.netcheck, type: .info)
}

enum NetworkAccessible {
    case unknown
    case available
    case unavailable
}

struct NetworkAnalyzerUrlResponse {
    let url: String
    var status: NetworkAccessible
}

public class NetworkAnalyzer: NSObject, URLSessionDelegate {
    private var active: Bool
    private var checker: ResponseChecker
    private var session: URLSession?
    private var monitor: NWPathMonitor?

    // explicit dispatch queue for the NWPathMonitor
    private let queue = DispatchQueue(label: "netmonitor")

    // references the dataTask objects for validating URLs indexed by string/URL
    // - gives us a handle the cancel them if needed...
    private var dataTasks: [String: URLSessionDataTask]
    private var dataTaskResponses: [String: NetworkAnalyzerUrlResponse]

    private var diagnosticText: String = "No diagnostic availaable."

    //        = [
    //        "https://www.google.com/",
    //        "https://www.pandora.com/",
    //        "https://squareup.com/",
    //        "https://www.eldiablocoffee.com/",
    //        "https://www.facebook.com/"
    //    ]
    public var urlsToValidate: [String]
    public var wifiRouter: String

    // encapsulate but expose the specifics for the PATH to be able check
    // the status of it:
    //
    // switch path.status {
    //   case .satisfied:
    //   case .requiresConnection:
    //   case .unsatisfied:
    // }
    public var path: NWPath? { // read-only 'computed' property
        return monitor?.currentPath
    }

    public init(wifi wifiRouter: String, urlsToCheck: [String]) {
        active = false
        dataTasks = [:]
        dataTaskResponses = [:]
        urlsToValidate = urlsToCheck
        self.wifiRouter = wifiRouter
        checker = ResponseChecker(host: wifiRouter)
        super.init()

        session = setupURLSession()
        monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor?.pathUpdateHandler = networkPathUpdate
    }

    public func start() {
        os_log("Activating network analyzer!", log: OSLog.netcheck, type: .info)
        active = true
        monitor?.start(queue: queue)
    }

    public func stop() {
        os_log("Deactivating network analyzer!", log: OSLog.netcheck, type: .info)
        // immediately cease all network operations in URLSession
        session?.invalidateAndCancel()
        monitor?.cancel()
        active = false
        // reset the session for running again in the future
        session = setupURLSession()
    }

    // setup and configure the URLSession for checking URLs
    private func setupURLSession() -> URLSession {
        let urlRequestQueue = OperationQueue()
        urlRequestQueue.name = "urlRequests"
        urlRequestQueue.qualityOfService = .userInteractive

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 5
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocol = .sslProtocolAll
        return URLSession(configuration: configuration,
                          delegate: self,
                          delegateQueue: urlRequestQueue)
    }

    // callbacks and the cascade of checking

    private func networkPathUpdate(_ path: NWPath) {
        // called when the network path changes
        switch path.status {
        case .satisfied:
            os_log("NWPath update: satisfied", log: OSLog.netcheck, type: .debug)
        case .requiresConnection:
            os_log("NWPath update: requiresConnection", log: OSLog.netcheck, type: .debug)
        case .unsatisfied:
            os_log("NWPath update: unsatisfied", log: OSLog.netcheck, type: .debug)
        }

        do {
            resetAndCheckURLS()
            try checker.checkSocketResponse()
        }
        catch {
            os_log("Error while invoking socket response to the WIFI router: %{public}@",
                   log: OSLog.netcheck, type: .error, String(describing: error))
        }
    }

    private func wifiPingCheckCallback(_: ResponseChecker, _ result: Bool) {
        // test each of the URLs for access
        DispatchQueue.main.async { [weak self] in
            if result {
                self?.diagnosticText = "The WIFI is accessible locally, so any problems with the internet "
                self?.diagnosticText += "is 'upstream' and not local."
                self?.diagnosticText += "\n\n"
                self?.diagnosticText += "If the internet is unavailable, you should contact the service "
                self?.diagnosticText += "provider, as they don't appear to be providing a conection currently."
            }
            else {
                self?.diagnosticText = "The WIFI is not accessible, so it's probably worth restarting the "
                self?.diagnosticText += "WIFI router."
            }
        }
    }

    private func resetAndCheckURLS() {
        session?.reset {
            // test each of the URLs for access
            for urlString in self.urlsToValidate {
                let datatask = self.testURLaccess(urlString: urlString)
                self.dataTasks[urlString] = datatask
                self.dataTaskResponses[urlString] = NetworkAnalyzerUrlResponse(url: urlString, status: .unknown)
            }
        }
    }

    private func testURLaccess(urlString: String) -> URLSessionDataTask? {
        guard let url = URL(string: urlString) else {
            // kind of an open question of if this would be better as an error
            // vs. logged/silent failure
            os_log("Couldn't make %{public}@ into a URL",
                   log: OSLog.netcheck, type: .error, urlString, urlString)
            return nil
        }
        os_log("creating dataTask to check: %{public}@",
               log: OSLog.netcheck, type: .info, urlString)
        let urlRequest = URLRequest(url: url)

        /*
         In your extension delegate’s applicationWillResignActive() method, cancel any outstanding
         tasks by calling the URLSessionTask object’s cancel() method.
         */

        let dataTask = session?.dataTask(with: urlRequest) { data, response, error in
            // clean up after ourselves...
            // defer { self.dataTask = nil }

            // check for errors
            guard error == nil else {
                os_log("%{public}@ error:  %{public}@",
                       log: OSLog.netcheck, type: .error, urlString, String(describing: error))
                self.dataTaskResponses[urlString]?.status = .unavailable
                return
            }
            // make sure we gots the data
            if data != nil,
                let response = response as? HTTPURLResponse {
                os_log("%{public}@ status code: %{public}d",
                       log: OSLog.netcheck, type: .error, urlString, response.statusCode)
                self.dataTaskResponses[urlString]?.status = .available
            }
        }
        dataTask?.resume()
        return dataTask
    }
}
