//
//  CNAButton.swift
//  CNA
//
//  Created by Joseph Heck on 3/13/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import UIKit

@IBDesignable
class CNAButton: UIButton {
    @IBInspectable var borderWidth: Int {
        set {
            layer.borderWidth = CGFloat(newValue)
        }
        get {
            return Int(layer.borderWidth)
        }
    }

    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
         // Drawing code
     }
     */
}
