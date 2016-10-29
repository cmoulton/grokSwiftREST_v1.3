//
//  MasterViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController {

  var detailViewController: DetailViewController? = nil
  var gists = [Gist]()


  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem

    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
    self.navigationItem.rightBarButtonItem = addButton
    if let split = self.splitViewController {
        let controllers = split.viewControllers
        self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    loadGists()
  }
  
  func loadGists() {
    GitHubAPIManager.sharedInstance.fetchPublicGists() {
      result in
      guard result.error == nil else {
        self.handleLoadGistsError(result.error!)
        return
      }
      if let fetchedGists = result.value {
        self.gists = fetchedGists
      }
      self.tableView.reloadData()
    }
  }
  
  func handleLoadGistsError(_ error: Error) {
    // TODO: show error
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  func insertNewObject(_ sender: Any) {
    let alert = UIAlertController(title: "Not Implemented",
                                  message: "Can't create new gists yet, will implement later",
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK",
                                  style: .default,
                                  handler: nil))
    self.present(alert, animated: true, completion: nil)
  }

  // MARK: - Segues

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let gist = gists[indexPath.row]
        if let controller = (segue.destination as? UINavigationController)?
          .topViewController as? DetailViewController {
          controller.detailItem = gist
          controller.navigationItem.leftBarButtonItem =
            self.splitViewController?.displayModeButtonItem
          controller.navigationItem.leftItemsSupplementBackButton = true
        }
      }
    }
  }

  // MARK: - Table View

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return gists.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell {
      let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
      let gist = gists[indexPath.row]
      cell.textLabel?.text = gist.description
      cell.detailTextLabel?.text = gist.ownerLogin
      cell.imageView?.image = nil
      if let urlString = gist.ownerAvatarURL {
        GitHubAPIManager.sharedInstance.imageFrom(urlString: urlString) {
          (image, error) in
          guard error == nil else {
            print(error!)
            return
          }
          if let cellToUpdate = self.tableView?.cellForRow(at: indexPath) {
            cellToUpdate.imageView?.image = image // will work fine even if image is nil
            // need to reload the view, which won't happen otherwise
            // since this is in an async call
            cellToUpdate.setNeedsLayout()
          }
        }
      }
      return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
      return false
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      gists.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array
      // and add a new row to the table view.
    }
  }

}

