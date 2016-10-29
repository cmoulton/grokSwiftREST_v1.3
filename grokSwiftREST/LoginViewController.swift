//
//  LoginViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit

protocol LoginViewDelegate: class {
  func didTapLoginButton()
}
class LoginViewController: UIViewController {
  weak var delegate: LoginViewDelegate?
  @IBAction func tappedLoginButton() {
    delegate?.didTapLoginButton()
  }
}
