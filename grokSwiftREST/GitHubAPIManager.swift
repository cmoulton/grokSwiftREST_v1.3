//
//  GitHubAPIManager.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire

enum GitHubAPIManagerError: Error {
  case network(error: Error)
  case apiProvidedError(reason: String)
  case authCouldNot(reason: String)
  case authLost(reason: String)
  case objectSerialization(reason: String)
}

class GitHubAPIManager {
  static let sharedInstance = GitHubAPIManager()
  
  func printPublicGists() -> Void {
    Alamofire.request(GistRouter.getPublic())
      .responseString { response in
        if let receivedString = response.result.value {
          print(receivedString)
        }
    }
  }
  
  func fetchPublicGists(completionHandler: @escaping (Result<[Gist]>) -> Void) {
    Alamofire.request(GistRouter.getPublic())
      .responseJSON { response in
        let result = self.gistArrayFromResponse(response: response)
        completionHandler(result)
    }
  }
  
  private func gistArrayFromResponse(response: DataResponse<Any>) -> Result<[Gist]> {
    guard response.result.error == nil else {
      print(response.result.error!)
      return .failure(GitHubAPIManagerError.network(error: response.result.error!))
    }
    
    // make sure we got JSON and it's an array
    guard let jsonArray = response.result.value as? [[String: Any]] else {
      print("didn't get array of gists object as JSON from API")
      return .failure(GitHubAPIManagerError.objectSerialization(reason:
        "Did not get JSON dictionary in response"))
    }
    
    // check for "message" errors in the JSON because this API does that
    if let jsonDictionary = response.result.value as? [String: Any],
      let errorMessage = jsonDictionary["message"] as? String {
      return .failure(GitHubAPIManagerError.apiProvidedError(reason: errorMessage))
    }
    
    // turn JSON in to gists
    var gists = [Gist]()
    for item in jsonArray {
      if let gist = Gist(json: item) {
        gists.append(gist)
      }
    }
    return .success(gists)
  }
}
