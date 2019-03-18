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

class ViewController: UIViewController, NetworkAnalyzerDelegate {
    private var urlLabels: [String: UILabel] = [:]
    private weak var analyzer: NetworkAnalyzer?

    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var overallAccessView: UIView!
    @IBOutlet private var diagnosticLabel: UILabel!
    @IBOutlet private var overallAccessLabel: UILabel!
    @IBOutlet private var diagnosticText: UITextView!
    @IBOutlet private var testButton: UIButton!

    // TEST BUTTON to force the URL checking
    @IBAction private func doTheStuff(_: UIButton) {
        analyzer?.checkURLs()
    }

    // DIAGNOSTIC ENVIRONMENT VARIABLE: CFNETWORK_DIAGNOSTICS
    // set to 0, 1, 2, or 3 - increasing for more diagnostic information from CFNetwork

    func networkAnalysisUpdate(path: NWPath?, wifiResponse: Bool) {
        if let pathStatus = path?.status {
            switch pathStatus {
            case .requiresConnection:
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessLabel.text = "Internet available"
                    UIView.animate(withDuration: 1, animations: {
                        self?.overallAccessView.backgroundColor = #colorLiteral(red: 0.9607843161, green: 0.7058823705, blue: 0.200000003, alpha: 1)
                        self?.diagnosticText.isHidden = true
                        self?.diagnosticLabel.isHidden = true
                    })
                }
            case .satisfied:
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessLabel.text = "Internet available"
                    UIView.animate(withDuration: 1, animations: {
                        self?.overallAccessView.backgroundColor = #colorLiteral(red: 0.5843137503, green: 0.8235294223, blue: 0.4196078479, alpha: 1)
                        self?.diagnosticText.isHidden = true
                        self?.diagnosticLabel.isHidden = true
                    })
                }
            case .unsatisfied:
                DispatchQueue.main.async { [weak self] in
                    self?.overallAccessLabel.text = "No Internet access"

                    if wifiResponse {
                        self?.diagnosticText.text = "The WIFI is accessible locally, so any problems with the internet "
                        self?.diagnosticText.text += "is 'upstream' and not local."
                        self?.diagnosticText.text += "\n\n"
                        self?.diagnosticText.text += "If the internet is unavailable, you should contact the service "
                        self?.diagnosticText.text += "provider, as they don't appear to be providing a conection "
                        self?.diagnosticText.text += "currently."
                    } else {
                        self?.diagnosticText.text = "The WIFI is not accessible, so it's probably worth restarting the "
                        self?.diagnosticText.text += "WIFI router."
                    }

                    UIView.animate(withDuration: 1, animations: {
                        self?.overallAccessView.backgroundColor = UIColor.red
                        self?.diagnosticText.isHidden = false
                        self?.diagnosticLabel.isHidden = false
                    })
                }
            }
        }
    }

    func urlUpdate(urlresponse: NetworkAnalyzerUrlResponse) {
        DispatchQueue.main.async { [weak self] in
            if let label = self?.urlLabels[urlresponse.url] {
                switch urlresponse.status {
                case .available:
                    UIView.animate(withDuration: 1, animations: {
                        // NOTE(heckj): this doesn't seem to "fade into green", which is what I hoped...
                        // https://www.ralfebert.de/ios-examples/uikit/swift-uicolor-picker/
                        // dark green
                        label.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
                    })
                case .unavailable:
                    UIView.animate(withDuration: 1, animations: {
                        label.textColor = UIColor.red
                    })
                case .unknown:
                    label.textColor = UIColor.lightGray
                }
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // swiftlint:disable:next force_cast
        let appdelegate = UIApplication.shared.delegate as! AppDelegate
        analyzer = appdelegate.analyzer
        analyzer?.delegate = self

        if let urlList = analyzer?.urlsToValidate {
            for urlString in urlList {
                let viewForURL = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
                viewForURL.text = urlString
                viewForURL.textColor = UIColor.gray
                viewForURL.textAlignment = NSTextAlignment.center
                urlLabels[urlString] = viewForURL
                stackView.addArrangedSubview(viewForURL)
            }
        }
        // Do any additional setup after loading the view, typically from a nib.
        getwifi()
    }

    func getwifi() {
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
}
