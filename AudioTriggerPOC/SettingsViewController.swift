//
//  SettingsViewController.swift
//  AudioTriggerPOC
//
//  Created by Aleksandar Mihailovski on 2018-01-30.
//  Copyright © 2018 Aleksandar Mihailovski. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!

    private let emailTextFieldValidator = EmailTextFieldValidator()
    private let userDefaults = UserDefaults()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.emailTextField.text = self.userDefaults.emailDestination
        if self.emailTextFieldValidator.validate(field: self.emailTextField) == nil {
            self.emailTextField.backgroundColor = UIColor.AudioTrigger.error
        } else {
            self.emailTextField.backgroundColor = UIColor.AudioTrigger.valid
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let email = self.emailTextFieldValidator.validate(field: textField) {
            self.userDefaults.emailDestination = email
            self.emailTextField.backgroundColor = UIColor.AudioTrigger.valid
        } else {
            self.emailTextField.backgroundColor = UIColor.AudioTrigger.error
        }
    }
}
