//
//  SampleDetailsViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-03-20.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

class SampleDetailsViewController: UIViewController {
    @IBOutlet weak var label: UILabel!

    fileprivate var sampleData: SampleableData?


    override func viewDidLoad() {
        super.viewDidLoad()

        label.text = sampleData?.prettyDescription()
    }

    class func create(for sampleData: SampleableData) -> SampleDetailsViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SampleDetailsViewController-SI")
            as! SampleDetailsViewController
        vc.sampleData = sampleData

        return vc
    }
}
