//
//  ViewController.swift
//  Coffeeshop Network Advisor
//
//  Created by Joseph Heck on 3/9/19.
//

import Network
import UIKit

class ViewController: UIViewController, URLSessionDelegate, URLSessionTaskDelegate {
    var dataTask: URLSessionDataTask?

    override func viewDidLoad() {
        super.viewDidLoad()
        print("View Loaded!")

        // Do any additional setup after loading the view, typically from a nib.
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let queue = DispatchQueue(label: "netmonitor")
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print(path.debugDescription, "is expensive? ", path.isExpensive, "is connected")
                DispatchQueue.main.async { [weak self] in
                    self?.view.backgroundColor = UIColor.green
                }
            } else {
                print(path.debugDescription, "is expensive? ", path.isExpensive, "is disconnected")
                DispatchQueue.main.async { [weak self] in
                    self?.view.backgroundColor = UIColor.red
                }
            }
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        guard let url = URL(string: "https://www.google.com/") else {
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
        print("task interval was: ", metrics.taskInterval)
        print("redirect count was: ", metrics.redirectCount)
        print("details...")
        let transactionMetricsList = metrics.transactionMetrics
        for metric in transactionMetricsList {
            print("request ", metric.request.debugDescription)
            print("to ", metric.request.url!)
            print("fetchStart ", metric.fetchStartDate!)
            // some of the rest of this may not actually exist if the request fails... need to check nils...
            print("domainLookupStartDate ", metric.domainLookupStartDate!)
            print("domainLookupEndDate ", metric.domainLookupEndDate!)
            print("connectStartDate ", metric.connectStartDate!)
            print("connectEndDate ", metric.connectEndDate!)
            print("requeststart ", metric.requestStartDate!)
            print("requestEnd ", metric.requestEndDate!)
            print("responseStart ", metric.responseStartDate!)
            print("responseEnd ", metric.responseEndDate!)
        }
    }
}
