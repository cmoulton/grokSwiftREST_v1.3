//
//  DetailViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit
import SafariServices
import BRYXBanner

class DetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  @IBOutlet weak var tableView: UITableView!
  var alertController: UIAlertController?
  var isStarred: Bool?
  var errorBanner: Banner?
  
  func configureView() {
    if let _ = self.gist {
      fetchStarredStatus()
      if let detailsView = self.tableView {
        detailsView.reloadData()
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.configureView()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    if let existingBanner = self.errorBanner {
      existingBanner.dismiss()
    }
    super.viewWillDisappear(animated)
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
  
  func fetchStarredStatus() {
    guard let gistId = gist?.id else {
      return
    }
    GitHubAPIManager.sharedInstance.isGistStarred(gistId) {
      result in
      guard result.error == nil else {
        print(result.error!)
        switch result.error! {
        case GitHubAPIManagerError.authLost:
          self.alertController = UIAlertController(
            title: "Could not get starred status",
            message: result.error!.localizedDescription,
            preferredStyle: .alert)
          // add ok button
          let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
          self.alertController?.addAction(okAction)
          self.present(self.alertController!, animated: true, completion: nil)
          return
        case GitHubAPIManagerError.network(let innerError as NSError):
          if innerError.domain != NSURLErrorDomain {
            break
          }
          if innerError.code == NSURLErrorNotConnectedToInternet {
            self.showNotConnectedBanner(title: "Could not get starred status",
              message: "Sorry, whether your gist is starred couldn't get retrieved from GitHub. "
               + "Maybe GitHub is down or you don't have an internet connection.")
            return
          }
        default:
          break
        }
        return
      }
      if let status = result.value, self.isStarred == nil {
        // just got it
        self.isStarred = status
        self.tableView?.insertRows(at: [IndexPath(row: 2, section: 0)],
                                   with: .automatic)
      }
    }
  }
  
  func starThisGist() {
    guard let gistId = gist?.id else {
      return
    }
    GitHubAPIManager.sharedInstance.starGist(gistId) {
      (error) in
      if let error = error {
        print(error)
        let errorMessage: String?
        switch error {
        case GitHubAPIManagerError.authLost:
          errorMessage = error.localizedDescription
        default:
          errorMessage = "Sorry, your gist couldn't be starred. " +
          "Maybe GitHub is down or you don't have an internet connection."
          break
        }
        if let errorMessage = errorMessage {
          self.alertController = UIAlertController(title: "Could not get star gist",
                                                   message: errorMessage,
                                                   preferredStyle: .alert)
          // add ok button
          let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
          self.alertController?.addAction(okAction)
          self.present(self.alertController!, animated: true, completion: nil)
          return
        }
      } else {
        self.isStarred = true
        self.tableView.reloadRows(
          at: [IndexPath(row: 2, section: 0)],
          with: .automatic)
      }
    }
  }
  
  func unstarThisGist() {
    guard let gistId = gist?.id else {
      return
    }
    GitHubAPIManager.sharedInstance.unstarGist(gistId) {
      (error) in
      if let error = error {
        print(error)
        let errorMessage: String?
        switch error {
        case GitHubAPIManagerError.authLost:
          errorMessage = error.localizedDescription
        default:
          errorMessage = "Sorry, your gist couldn't be unstarred. " +
          "Maybe GitHub is down or you don't have an internet connection."
          break
        }
        if let errorMessage = errorMessage {
          self.alertController = UIAlertController(title: "Could not get unstar gist",
                                                   message: errorMessage,
                                                   preferredStyle: .alert)
          // add ok button
          let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
          self.alertController?.addAction(okAction)
          self.present(self.alertController!, animated: true, completion: nil)
          return
        }
      } else {
        self.isStarred = false
        self.tableView.reloadRows(
          at: [IndexPath(row: 2, section: 0)],
          with: .automatic)
      }
    }
  }
  
  func showNotConnectedBanner(title: String, message: String) {
    // show not connected error & tell em to try again when they do have a connection
    self.errorBanner = Banner(title: title,
                              subtitle: message,
                              image: nil,
                              backgroundColor: UIColor.orange)
    self.errorBanner?.dismissesOnSwipe = true
    self.errorBanner?.show(duration: nil)
  }
  
  // MARK: - Table View
  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      if let _ = isStarred {
        return 3
      }
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
    switch (indexPath.section, indexPath.row, isStarred) {
    case (0, 0, _):
      cell.textLabel?.text = gist?.gistDescription
    case (0, 1, _):
      cell.textLabel?.text = gist?.ownerLogin
    case (0, 2, .none):
      cell.textLabel?.text = ""
    case (0, 2, .some(true)):
      cell.textLabel?.text = "Unstar"
    case (0, 2, .some(false)):
      cell.textLabel?.text = "Star"
    default: // section 1
      cell.textLabel?.text = gist?.files?[indexPath.row].filename
    }
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch (indexPath.section, indexPath.row, isStarred) {
    case (0, 2, .some(true)):
      unstarThisGist()
    case (0, 2, .some(false)):
      starThisGist()
    case (1, _, _):
      guard let file = gist?.files?[indexPath.row],
        let urlString = file.raw_url,
        let url = URL(string: urlString) else {
          return
      }
      let safariViewController = SFSafariViewController(url: url)
      safariViewController.title = file.filename
      self.navigationController?.pushViewController(safariViewController, animated: true)
    default:
      print("No-op")
    }
  }
}

