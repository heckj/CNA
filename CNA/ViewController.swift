//
//  ViewController.swift
//  Coffeeshop Network Advisor
//
//  Created by Joseph Heck on 3/9/19.
//  Copyright © 2019 Joseph Heck. All rights reserved.
//

import Charts
import Network
import SystemConfiguration.CaptiveNetwork
import UIKit

class ViewController: UIViewController, URLSessionDelegate, URLSessionTaskDelegate {
    var dataTask: URLSessionDataTask?
    @IBOutlet weak private var overallAccessView: UIView!
    @IBOutlet weak private var overallAccessLabel: UILabel!
    @IBOutlet weak private var diagnosticText: UITextView!
    @IBOutlet weak private var textView: UITextView!

    // DIAGNOSTIC ENVIRONMENT VARIABLE: CFNETWORK_DIAGNOSTICS
    // set to 0, 1, 2, or 3 - increasing for more diagnostic information from CFNetwork

    private func startPinging() {
        let ping = SwiftyPing(host: "192.168.1.1",
                              configuration: PingConfiguration(interval: 1),
                              queue: DispatchQueue.global())
        ping?.observer = { ping, response in
            DispatchQueue.main.async {
                self.textView.text.append(
                    contentsOf: "\nPing #\(response.sequenceNumber): \(response.duration * 1000) ms")
                self.textView.scrollRangeToVisible(NSRange(location: self.textView.text.count - 1, length: 1))
            }
        }
        ping?.start()
    }

    private func getwifi() {
        // https://developer.apple.com/documentation/systemconfiguration/1614126-cncopycurrentnetworkinfo?language=objc
        // ref: https://stackoverflow.com/questions/31755692/swift-cncopysupportedinterfaces-not-valid
        // (cause Apple's docs on how to use this are shit)
        let arrayOfInterfaces = CNCopySupportedInterfaces()
        // returns 'nil' on the simulator...
        if let arrayOfInterfaces = arrayOfInterfaces as? [CFString] {
            for interface in arrayOfInterfaces {
                let foo = CNCopyCurrentNetworkInfo(interface)
                print("Wifi information: ", foo as Any)
            }
        }

        guard let unwrappedCFArrayInterfaces = CNCopySupportedInterfaces() else {
            print("this must be a simulator, no interfaces found")
            return
        }
        guard let swiftInterfaces = (unwrappedCFArrayInterfaces as NSArray) as? [String] else {
            print("System error: did not come back as array of Strings")
            return
        }
        for interface in swiftInterfaces {
            print("Looking up SSID info for \(interface)") // en0
            guard let unwrappedCFDictionaryForInterface = CNCopyCurrentNetworkInfo(interface as CFString) else {
                print("System error: \(interface) has no information")
                return
            }
            guard let SSIDDict = (unwrappedCFDictionaryForInterface as NSDictionary) as? [String: AnyObject] else {
                print("System error: interface information is not a string-keyed dictionary")
                return
            }
            for dictionaryKey in SSIDDict.keys {
                print("\(dictionaryKey): \(SSIDDict[dictionaryKey]!)")
            }
        }
    }

    private func monitorNWPath() {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let queue = DispatchQueue(label: "netmonitor")
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print(path.debugDescription, "is expensive? ", path.isExpensive, "is connected")
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessView.backgroundColor = UIColor.green
                    self?.overallAccessLabel.text = "Internet available"
                }
            } else {
                print(path.debugDescription, "is expensive? ", path.isExpensive, "is disconnected")
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessView.backgroundColor = UIColor.red
                    self?.overallAccessLabel.text = "No Internet access"
                }
            }
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.getwifi()
        self.startPinging()
        self.monitorNWPath()

        let urlRequestQueue = OperationQueue()
        urlRequestQueue.name = "urlRequests"
        urlRequestQueue.qualityOfService = .userInteractive

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 1
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocol = .sslProtocolAll
        let session = URLSession(configuration: configuration,
                                 delegate: self,
                                 delegateQueue: urlRequestQueue)

        guard let url = URL(string: "https://192.168.1.1/") else {
            print("Couldn't make this URL")
            return
        }
        let urlRequest = URLRequest(url: url)

        dataTask = session.dataTask(with: urlRequest) { data, response, error in
            // clean up after ourselves...
            defer { self.dataTask = nil }

            // check for errors
            guard error == nil else {
                print("Error calling the URL")
                print(error!)
                return
            }
            // make sure we gots the data
            if let data = data,
                let response = response as? HTTPURLResponse {
                print("resulting status code is ", response.statusCode)
                print("data returned is ", data)
            }
        }
        dataTask?.resume()
    }

    // URLSessionTaskDelegate methods
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        // check the metrics
        print("task duration (ms): ", metrics.taskInterval.duration * 1000)
        print("redirect count was: ", metrics.redirectCount)
        print("details...")
        let transactionMetricsList = metrics.transactionMetrics
        for metric in transactionMetricsList {
            print("request ", metric.request.debugDescription)
            print("fetchStart ", metric.fetchStartDate!)
            // some of the rest of this may not actually exist if the request fails... need to check nils...

            if let domainStart = metric.domainLookupStartDate,
                let domainEnd = metric.domainLookupEndDate,
                let connectStart = metric.connectStartDate,
                let connectEnd = metric.connectEndDate,
                let requestStart = metric.connectStartDate,
                let requestEnd = metric.connectEndDate,
                let responseStart = metric.responseStartDate,
                let responseEnd = metric.responseEndDate {
                print("domainDuration (ms) ", domainEnd.timeIntervalSince(domainStart) * 1000)
                print("connectDuration (ms) ", connectEnd.timeIntervalSince(connectStart) * 1000)
                print("requestDuration (ms) ", requestEnd.timeIntervalSince(requestStart) * 1000)
                print("responseDuration (ms) ", responseEnd.timeIntervalSince(responseStart) * 1000)
            }
        }
    }
}
