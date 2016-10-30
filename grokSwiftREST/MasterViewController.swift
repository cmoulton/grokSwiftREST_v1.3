//
//  MasterViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit
import PINRemoteImage
import SafariServices
import Alamofire
import BRYXBanner

class MasterViewController: UITableViewController, LoginViewDelegate,
SFSafariViewControllerDelegate {
  var safariViewController: SFSafariViewController?
  var detailViewController: DetailViewController? = nil
  var gists = [Gist]()
  var nextPageURLString: String?
  var isLoading = false
  var dateFormatter = DateFormatter()
  @IBOutlet weak var gistSegmentedControl: UISegmentedControl!
  var errorBanner: Banner?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    if let split = self.splitViewController {
      let controllers = split.viewControllers
      self.detailViewController = (controllers[controllers.count-1] as!
        UINavigationController).topViewController as? DetailViewController
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
    
    // add refresh control for pull to refresh
    if (self.refreshControl == nil) {
      self.refreshControl = UIRefreshControl()
      self.refreshControl?.addTarget(self,
                                     action: #selector(refresh(sender:)),
                                     for: .valueChanged)
      self.dateFormatter.dateStyle = .short
      self.dateFormatter.timeStyle = .long
    }
    
    super.viewWillAppear(animated)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if (!GitHubAPIManager.sharedInstance.isLoadingOAuthToken) {
      loadInitialData()
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    if let existingBanner = self.errorBanner {
      existingBanner.dismiss()
    }
    super.viewWillDisappear(animated)
  }
  
  func loadInitialData() {
    isLoading = true
    GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler = { error in
      guard error == nil else {
        print(error!)
        self.isLoading = false
        switch error! {
        case GitHubAPIManagerError.network(let innerError as NSError):
          if innerError.domain != NSURLErrorDomain {
            break
          }
          if innerError.code == NSURLErrorNotConnectedToInternet {
            let path:Path =
              [.Public, .Starred, .MyGists][self.gistSegmentedControl.selectedSegmentIndex]
            if let archived:[Gist] = PersistenceManager.loadArray(path: path) {
              self.gists = archived
            } else {
              self.gists = [] // don't have any saved gists
            }
            self.tableView.reloadData()
            
            self.showNotConnectedBanner()
            return
          }
        default:
          break
        }
        
        // Something went wrong, try again
        self.showOAuthLoginView()
        return
      }
      
      if let _ = self.safariViewController {
        self.dismiss(animated: false) {}
      }
      self.loadGists(urlToLoad: nil)
    }
    if (!GitHubAPIManager.sharedInstance.hasOAuthToken()) {
      showOAuthLoginView()
      return
    }
    loadGists(urlToLoad: nil)
  }
  
  func showOAuthLoginView() {
    GitHubAPIManager.sharedInstance.isLoadingOAuthToken = true
    let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
    guard let loginVC = storyboard.instantiateViewController(withIdentifier:
      "LoginViewController") as? LoginViewController else {
        assert(false, "Misnamed view controller")
        return
    }
    loginVC.delegate = self
    self.present(loginVC, animated: true, completion: nil)
  }
  
  func loadGists(urlToLoad: String?) {
    self.isLoading = true
    let completionHandler: (Result<[Gist]>, String?) -> Void = {
      (result, nextPage) in
      self.isLoading = false
      self.nextPageURLString = nextPage
      
      // tell refresh control it can stop showing up now
      if self.refreshControl != nil,
        self.refreshControl!.isRefreshing {
        self.refreshControl?.endRefreshing()
      }
      
      guard result.error == nil else {
        self.handleLoadGistsError(result.error!)
        return
      }
      
      guard let fetchedGists = result.value else {
        print("no gists fetched")
        return
      }
      
      if urlToLoad == nil {
        // empty out the gists because we're not loading another page
        self.gists = []
      }
      
      self.gists += fetchedGists
      
      let path:Path = [.Public, .Starred, .MyGists][self.gistSegmentedControl.selectedSegmentIndex]
      let success = PersistenceManager.saveArray(arrayToSave: self.gists, path: path)
      if !success {
        self.showOfflineSaveFailedBanner()
      }
      
      let now = Date()
      let updateString = "Last Updated at " + self.dateFormatter.string(from: now)
      self.refreshControl?.attributedTitle = NSAttributedString(string: updateString)
      
      self.tableView.reloadData()
    }
    
    switch gistSegmentedControl.selectedSegmentIndex {
    case 0:
      GitHubAPIManager.sharedInstance.fetchPublicGists(pageToLoad: urlToLoad,
                                                       completionHandler: completionHandler)
    case 1:
      GitHubAPIManager.sharedInstance.fetchMyStarredGists(pageToLoad: urlToLoad,
                                                          completionHandler: completionHandler)
    case 2:
      GitHubAPIManager.sharedInstance.fetchMyGists(pageToLoad: urlToLoad,
                                                   completionHandler: completionHandler)
    default:
      print("got an index that I didn't expect for selectedSegmentIndex")
    }
  }
  
  func handleLoadGistsError(_ error: Error) {
    print(error)
    nextPageURLString = nil
    isLoading = false
    self.isLoading = false
    switch error {
    case GitHubAPIManagerError.authLost:
      self.showOAuthLoginView()
      return
    case GitHubAPIManagerError.network(let innerError as NSError):
      // check the domain
      if innerError.domain != NSURLErrorDomain {
        break
      }
      // check the code:
      if innerError.code == NSURLErrorNotConnectedToInternet {
        showNotConnectedBanner()
        return
      }
    default:
      break
    }
  }
  
  func showNotConnectedBanner() {
    // check for existing banner
    if let existingBanner = self.errorBanner {
      existingBanner.dismiss()
    }
    // show not connected error & tell em to try again when they do have a connection
    self.errorBanner = Banner(title: "No Internet Connection",
      subtitle: "Could not load gists." +
      " Try again when you're connected to the internet",
      image: nil,
      backgroundColor: .red)
    self.errorBanner?.dismissesOnSwipe = true
    self.errorBanner?.show(duration: nil)
  }
  
  func showOfflineSaveFailedBanner() {
    if let existingBanner = self.errorBanner {
      existingBanner.dismiss()
    }
    self.errorBanner = Banner(title: "Could not save gists to view offline",
                              subtitle: "Your iOS device is almost out of free space.\n" +
      "You will only be able to see your gists when you have an internet connection.",
                              image: nil,
                              backgroundColor: UIColor.orange)
    self.errorBanner?.dismissesOnSwipe = true
    self.errorBanner?.show(duration: nil)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func insertNewObject(_ sender: Any) {
    let createVC = CreateGistViewController(nibName: nil, bundle: nil)
    self.navigationController?.pushViewController(createVC, animated: true)
  }
  
  // MARK: - Segues
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let gist = gists[indexPath.row]
        if let controller = (segue.destination as? UINavigationController)?
          .topViewController as? DetailViewController {
          controller.gist = gist
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
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    
    let gist = gists[indexPath.row]
    cell.textLabel?.text = gist.gistDescription
    cell.detailTextLabel?.text = gist.ownerLogin
    
    // set cell.imageView to display image at gist.ownerAvatarURL
    if let urlString = gist.ownerAvatarURL,
      let url = URL(string: urlString) {
      cell.imageView?.pin_setImage(from: url, placeholderImage:
      UIImage(named: "placeholder.png")) { result in
        if let cellToUpdate = self.tableView?.cellForRow(at: indexPath) {
          cellToUpdate.setNeedsLayout()
        }
      }
    } else {
      cell.imageView?.image = UIImage(named: "placeholder.png")
    }
    
    // See if we need to load more gists
    if !isLoading {
      let rowsLoaded = gists.count
      let rowsRemaining = rowsLoaded - indexPath.row
      let rowsToLoadFromBottom = 5
      if rowsRemaining <= rowsToLoadFromBottom {
        if let nextPage = nextPageURLString {
          self.loadGists(urlToLoad: nextPage)
        }
      }
    }
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return gistSegmentedControl.selectedSegmentIndex == 2
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let gistToDelete = gists[indexPath.row]
      guard let idToDelete = gistToDelete.id else {
        return
      }
      // remove from array of gists
      gists.remove(at: indexPath.row)
      // remove table view row
      tableView.deleteRows(at: [indexPath], with: .fade)
      // delete from API
      GitHubAPIManager.sharedInstance.deleteGist(idToDelete) { error in
        if let error = error {
          print(error)
          // Put it back
          self.gists.insert(gistToDelete, at: indexPath.row)
          tableView.insertRows(at: [indexPath], with: .right)
          // tell them it didn't work
          let alertController = UIAlertController(title: "Could not delete gist",
            message: "Sorry, your gist couldn't be deleted. Maybe GitHub is "
              + "down or you don't have an internet connection.",
            preferredStyle: .alert)
          // add ok button
          let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
          alertController.addAction(okAction)
          // show the alert
          self.present(alertController, animated:true, completion: nil)
        }
      }
    } else if editingStyle == .insert {
      // Create a new instance of the appropriate class, insert it into the array
      // and add a new row to the table view.
    }
  }
  
  // MARK: - Pull to Refresh
  func refresh(sender: Any) {
    GitHubAPIManager.sharedInstance.isLoadingOAuthToken = false
    nextPageURLString = nil // so it doesn't try to append the results
    GitHubAPIManager.sharedInstance.clearCache()
    loadInitialData()
  }
  
  // MARK: - LoginViewDelegate
  func didTapLoginButton() {
    self.dismiss(animated: false) {
      guard let authURL = GitHubAPIManager.sharedInstance.URLToStartOAuth2Login() else {
        let error = GitHubAPIManagerError.authCouldNot(reason:
          "Could not obtain an OAuth token")
        GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler?(error)
        return
      }
      self.safariViewController = SFSafariViewController(url: authURL)
      self.safariViewController?.delegate = self
      guard let webViewController = self.safariViewController else {
        return
      }
      self.present(webViewController, animated: true, completion: nil)
    }
  }
  
  // MARK: - Safari View Controller Delegate
  func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad
    didLoadSuccessfully: Bool) {
    // Detect not being able to load the OAuth URL
    if (!didLoadSuccessfully) {
      controller.dismiss(animated: true, completion: nil)
      GitHubAPIManager.sharedInstance.isAPIOnline { isOnline in
        if !isOnline {
          print("error: api offline")
          let innerError = NSError(domain: NSURLErrorDomain,
             code: NSURLErrorNotConnectedToInternet,
             userInfo: [NSLocalizedDescriptionKey:
              "No Internet Connection or GitHub is Offline",
              NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"])
          let error = GitHubAPIManagerError.network(error: innerError)
          GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler?(error)
        }
      }
    }
  }
  
  // MARK: - IBActions
  @IBAction func segmentedControlValueChanged(sender: UISegmentedControl) {
    // clear out the table view
    gists = []
    tableView.reloadData()
    // only show add & edit buttons for my gists
    if (gistSegmentedControl.selectedSegmentIndex == 2) {
      self.navigationItem.leftBarButtonItem = self.editButtonItem
      let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                      target: self,
                                      action: #selector(insertNewObject(_:)))
      self.navigationItem.rightBarButtonItem = addButton
    } else {
      self.navigationItem.leftBarButtonItem = nil
      self.navigationItem.rightBarButtonItem = nil
    }
    // then load the new list of gists
    loadGists(urlToLoad: nil)
  }
}

