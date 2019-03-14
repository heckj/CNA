//
//  CNAPulseView.swift
//  CNA
//
//  Created by Joseph Heck on 3/13/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import UIKit

@IBDesignable
class CNAPulseView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        finishInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        finishInit()
    }

    private func finishInit() {
        self.backgroundColor = UIColor.clear

//        let pulseOrigin = CGPoint(x: 80, y:80)
//        let circleView = pulseCircleView(frame:
//            CGRect(origin: pulseOrigin, size: CGSize(width: 30, height: 30))
//        )
//        circleView.alpha = 1.0
//        sampleview.addSubview(self.view)
//        // .autoreverse,
//        //  .curveLinear
//        // .beginFromCurrentState,
//        // .allowAnimatedContent,
//        UIView.animate(withDuration: 1.6,
//                       delay: 0.0,
//                       options: [.repeat
//            ],
//                       animations: {
//                        circleView.alpha = 0.2
//                        circleView.bounds = CGRect(origin: pulseOrigin,
//                                                   size: CGSize(width: 100, height: 100))
//        })
    }

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            context.setLineWidth(4.0)
            UIColor.blue.set()
            let center = CGPoint(x: frame.size.width/2.0, y: frame.size.height/2.0)
            let radius = (frame.size.width - 10)/2.0
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2.0, clockwise: true)
            context.strokePath()
        }
    }
}
