//
//  NetworkAnalyzerDelegate.swift
//  CNA
//
//  Created by Joseph Heck on 3/18/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import Foundation
import Network

protocol NetworkAnalyzerDelegate: AnyObject {
    // called when new diagnostic info/network state is available
    func networkAnalysisUpdate(path: NWPath?, wifiResponse: Bool)

    // called when one of the URLs being checked has updated data
    func urlUpdate(urlresponse: NetworkAnalyzerUrlResponse)
}
