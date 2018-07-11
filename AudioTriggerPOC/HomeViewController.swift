//
//  HomeViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-07-11.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

    @IBOutlet var iconImage: UIImageView!

    fileprivate let greenBack = UIColor(red:0.17,
                                        green:0.67,
                                        blue:0.48,
                                        alpha:1.00)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = greenBack
        self.iconImage.alpha = 0.5
    }

}
