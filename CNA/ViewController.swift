//
//  ViewController.swift
//  Coffeeshop Network Advisor
//
//  Created by Joseph Heck on 3/9/19.
//

import Network
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        print("View Loaded!")
        // Do any additional setup after loading the view, typically from a nib.
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let queue = DispatchQueue(label: "netmonitor")
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                print("Connected!")
            } else {
                print("Not connected")
            }
            print(path.debugDescription, "is expensive? ", path.isExpensive)
        }
    }
}
