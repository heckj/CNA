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
        backgroundColor = UIColor.clear

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
    override func draw(_: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            context.setLineWidth(4.0)
            UIColor.blue.set()
            let center = CGPoint(x: frame.size.width / 2.0, y: frame.size.height / 2.0)
            let radius = (frame.size.width - 10) / 2.0
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2.0, clockwise: true)
            context.strokePath()
        }
    }

    // I think the visual effect I want to have here would start with a solid circle
    // fading "into" existance from nothing quite quickly (alpha -> 1, duration=0.1/0.2),
    // then transitioning to a animation expanding the circle and decreasing it's alpha
    // - going from 1.0 down to .2/.25 or so, and tripling the size. Finally the size
    // stays consistent and the last animation triggers, which is just fading out the
    // remaining alpha, ideally at the same speed that it was fading during the pulse
    // "expansion"
    //
    // it might make sense to try this whole setup with UIViewPropertyAnimator since I
    // want to chain multiple sequences together. There's a nice overview at
    // https://useyourloaf.com/blog/quick-guide-to-property-animators/
    // there's some sample playground stuff at
    // https://github.com/kharrison/Property-Animators/blob/master/PropertyAnimators.playground/Contents.swift

    // there's a nice WWDC session showing using this to make animated controls and
    // interactions within a view that's really sweet: WWDC2017 session 230:
    // https://developer.apple.com/wwdc17/230
    // there's also UIView.animateKeyframes - but it seems slightly more limited than
    // the propertyAnimator setup, although maybe not for my needs.
    // https://medium.com/the-aesthetic-programmer/chaining-uiview-animations-with-animatekeyframes-466b5eaf9568
}
