//
//  MainViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    @IBOutlet weak var outputTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.outputTextView.text = "ALL PROCESS OUTPUT:"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension MainViewController {
    fileprivate func logToOutput(_ text: String) {
        //Add newline
        self.outputTextView.text.append("\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let datePrefix = dateFormatter.string(from: Date())

        //Add "DATE: text"
        self.outputTextView.text.append(datePrefix)
        self.outputTextView.text.append(": ")
        self.outputTextView.text.append(text)
    }
}
