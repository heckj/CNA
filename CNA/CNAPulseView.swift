//
//  CNAPulseView.swift
//  CNA
//
//  Created by Joseph Heck on 3/13/19.
//  Copyright © 2019 BackDrop. All rights reserved.
//

import UIKit

class CNAPulseView: UIView {
    @IBOutlet private weak var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        xibLoad()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibLoad()
    }

    private func xibLoad() {
        // referenced from code at https://theswiftdev.com/2018/10/16/custom-uiview-subclass-from-a-xib-file/
        let name = String(describing: type(of: self))
        let nib = UINib(nibName: name, bundle: .main)
        nib.instantiate(withOwner: self, options: nil)

        // next: append the container to our view
        self.addSubview(self.contentView)
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.contentView.topAnchor.constraint(equalTo: self.topAnchor),
            self.contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])
    }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
}
