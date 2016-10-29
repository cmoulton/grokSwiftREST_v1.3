//
//  DetailViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit
import SafariServices

class DetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  @IBOutlet weak var tableView: UITableView!

  func configureView() {
    if let detailsView = self.tableView {
      detailsView.reloadData()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.configureView()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  var gist: Gist? {
    didSet {
        // Update the view.
        self.configureView()
    }
  }
  
  // MARK: - Table View
  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 2
    } else {
      return gist?.files?.count ?? 0
    }
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 {
      return "About"
    } else {
      return "Files"
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
      let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
      switch (indexPath.section, indexPath.row) {
      case (0, 0):
        cell.textLabel?.text = gist?.description
      case (0, 1):
        cell.textLabel?.text = gist?.ownerLogin
      default: // section 1
        cell.textLabel?.text = gist?.files?[indexPath.row].filename
      }
      return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == 1 {
      guard let file = gist?.files?[indexPath.row],
        let urlString = file.raw_url,
        let url = URL(string: urlString) else {
          return
      }
      let safariViewController = SFSafariViewController(url: url)
      safariViewController.title = file.filename
      self.navigationController?.pushViewController(safariViewController, animated: true)
    }
  }
}

