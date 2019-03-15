//
//  ViewController.swift
//  Coffeeshop Network Advisor
//
//  Created by Joseph Heck on 3/9/19.
//  Copyright © 2019 Joseph Heck. All rights reserved.
//

import Charts
import Network
//import SwiftyPing
import SystemConfiguration.CaptiveNetwork
import UIKit

class ViewController: UIViewController, URLSessionDelegate, URLSessionTaskDelegate {
    private var dataTask: URLSessionDataTask?
    // URLs to check and validate
    private var urlsToValidate: [String] = [
        "https://www.google.com/",
        "https://www.pandora.com/",
        "https://squareup.com/",
        "https://www.eldiablocoffee.com/",
        "https://www.facebook.com/"
    ]
    private var urlLabels: [String: UILabel] = [:]
    private var session: URLSession?
    private var monitor: NWPathMonitor?

    @IBOutlet weak private var stackView: UIStackView!
    @IBOutlet weak private var overallAccessView: UIView!
    @IBOutlet weak private var diagnosticLabel: UILabel!
    @IBOutlet weak private var overallAccessLabel: UILabel!
    @IBOutlet weak private var diagnosticText: UITextView!
    @IBOutlet weak private var textView: UITextView!
    @IBOutlet weak private var testButton: UIButton!

    // TEST BUTTON to force the URL checking
    @IBAction private func doTheStuff(_ sender: UIButton) {
        if let monitor = self.monitor {
            print("monitor path: ", monitor.currentPath.status)
        }

        // test each of the URLs for access
        for urlString in urlsToValidate {
            self.urlLabels[urlString]?.textColor = UIColor.lightGray
        }
        for (urlString) in self.urlsToValidate {
            self.testURLaccess(urlString: urlString)
        }
//        self.startPinging()
//        UIView.animate(withDuration: 1, animations: {
//            self.textView.isHidden = false
//        })
    }

    // DIAGNOSTIC ENVIRONMENT VARIABLE: CFNETWORK_DIAGNOSTICS
    // set to 0, 1, 2, or 3 - increasing for more diagnostic information from CFNetwork

//    private func startPinging() {
//        let ping = SwiftyPing(host: "192.168.1.1",
//                              configuration: PingConfiguration(interval: 1, count: 3),
//                              queue: DispatchQueue.global())
//        ping?.responseClosure = { ping, response in
//            DispatchQueue.main.async {
//                self.textView.text.append(
//                    contentsOf: "\nPing #\(response.sequenceNumber): \(response.duration * 1000) ms")
//                self.textView.scrollRangeToVisible(NSRange(location: self.textView.text.count - 1, length: 1))
//            }
//        }
//        ping?.errorClosure = { ping, error in
//            DispatchQueue.main.async {
//                self.textView.text.append(
//                    contentsOf: "\nError #\(error.localizedDescription)")
//                self.textView.scrollRangeToVisible(NSRange(location: self.textView.text.count - 1, length: 1))
//            }
//        }
//        ping?.start()
//    }

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
        let queue = DispatchQueue(label: "netmonitor")
        self.monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor?.start(queue: queue)
        monitor?.pathUpdateHandler = { path in
            print("path status is ", path.status)
            if path.status == .satisfied {
                print(path.debugDescription, "is expensive? ", path.isExpensive, "is connected")
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessLabel.text = "Internet available"
                    UIView.animate(withDuration: 1, animations: {
                        self?.overallAccessView.backgroundColor = #colorLiteral(red: 0.5843137503, green: 0.8235294223, blue: 0.4196078479, alpha: 1)
                        self?.diagnosticText.isHidden = true
                        self?.diagnosticLabel.isHidden = true
                    })
                }
                // test each of the URLs for access
                for (urlString) in self.urlsToValidate {
                    self.testURLaccess(urlString: urlString)
                }
            } else {
                print(path.debugDescription, "is expensive? ", path.isExpensive, "is disconnected")
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessLabel.text = "No Internet access"
                    UIView.animate(withDuration: 1, animations: {
                        self?.overallAccessView.backgroundColor = UIColor.red
                        self?.diagnosticText.isHidden = false
                        self?.diagnosticLabel.isHidden = false
                    })
                }
            }
        }
    }

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

    private func testURLaccess(urlString: String) {
        guard let session = self.session else {
            print("Session has not been created for verifying URLs")
            return
        }
        guard let url = URL(string: urlString) else {
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
                DispatchQueue.main.async { [weak self] in
                    UIView.animate(withDuration: 1, animations: {
                        self?.urlLabels[urlString]?.textColor = UIColor.red
                    })
                }
                return
            }
            // make sure we gots the data
            if data != nil,
                let response = response as? HTTPURLResponse {
                print("resulting status code is ", response.statusCode)
                DispatchQueue.main.async { [weak self] in
                    UIView.animate(withDuration: 1, animations: {
                        // NOTE(heckj): this doesn't seem to "fade into green", which is what I hoped...
                        // https://www.ralfebert.de/ios-examples/uikit/swift-uicolor-picker/
                        // dark green
                        self?.urlLabels[urlString]?.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                    })
                }
            }
        }
        dataTask?.resume()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.session = setupURLSession()
        // Do any additional setup after loading the view, typically from a nib.
        for (urlString) in self.urlsToValidate {
            let viewForURL = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
            viewForURL.text = urlString
            viewForURL.textColor = UIColor.gray
            viewForURL.textAlignment = NSTextAlignment.center
            urlLabels[urlString] = viewForURL
            stackView.addArrangedSubview(viewForURL)
        }
        self.getwifi()

//        self.startPinging()

        self.monitorNWPath()
        // monitorPath cascades to validating the URLs IFF the path returns positively
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
