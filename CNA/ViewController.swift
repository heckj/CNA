//
//  ViewController.swift
//  Coffeeshop Network Advisor
//
//  Created by Joseph Heck on 3/9/19.
//

import Network
import SystemConfiguration.CaptiveNetwork
import UIKit

class ViewController: UIViewController, URLSessionDelegate, URLSessionTaskDelegate {
    var dataTask: URLSessionDataTask?
    @IBOutlet weak private var overallAccessView: UIView!
    @IBOutlet weak private var overallAccessLabel: UILabel!
    @IBOutlet weak private var diagnosticText: UITextView!

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
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("View Loaded!")

        self.getwifi()
        // Do any additional setup after loading the view, typically from a nib.
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

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 1
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = false
        configuration.tlsMinimumSupportedProtocol = .sslProtocolAll
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        guard let url = URL(string: "http://192.168.1.1/") else {
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
