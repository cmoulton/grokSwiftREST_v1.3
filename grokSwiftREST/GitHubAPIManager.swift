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
  
  // MARK: - API Calls
  func printPublicGists() -> Void {
    Alamofire.request(GistRouter.getPublic())
      .responseString { response in
        if let receivedString = response.result.value {
          print(receivedString)
        }
    }
  }
  
  func fetchPublicGists(pageToLoad: String?, completionHandler:
    @escaping (Result<[Gist]>, String?) -> Void) {
    if let urlString = pageToLoad {
      fetchGists(GistRouter.getAtPath(urlString), completionHandler: completionHandler)
    } else {
      fetchGists(GistRouter.getPublic(), completionHandler: completionHandler)
    }
  }
  
  func fetchGists(_ urlRequest: URLRequestConvertible,
                  completionHandler: @escaping (Result<[Gist]>, String?) -> Void) {
    Alamofire.request(urlRequest)
      .responseJSON { response in
        let result = self.gistArrayFromResponse(response: response)
        let next = self.parseNextPageFromHeaders(response: response.response)
        completionHandler(result, next)
    }
  }
  
  // MARK: - Helpers
  func imageFrom(urlString: String,
                 completionHandler: @escaping (UIImage?, Error?) -> Void) {
    let _ = Alamofire.request(urlString)
      .response { dataResponse in
        // use the generic response serializer that returns Data
        guard let data = dataResponse.data else {
          completionHandler(nil, dataResponse.error)
          return
        }
        let image = UIImage(data: data)
        completionHandler(image, nil)
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
  
  // MARK: - Pagination
  private func parseNextPageFromHeaders(response: HTTPURLResponse?) -> String? {
    guard let linkHeader = response?.allHeaderFields["Link"] as? String else {
      return nil
    }
    /* looks like: <https://...?page=2>; rel="next", <https://...?page=6>; rel="last" */
    // so split on ","
    let components = linkHeader.characters.split { $0 == "," }.map { String($0) }
    // now we have 2 lines like '<https://...?page=2>; rel="next"'
    for item in components {
      // see if it's "next"
      let rangeOfNext = item.range(of: "rel=\"next\"", options: [])
      guard rangeOfNext != nil else {
        continue
      }
      // this is the "next" item, extract the URL
      let rangeOfPaddedURL = item.range(of: "<(.*)>;",
                                        options: .regularExpression,
                                        range: nil,
                                        locale: nil)
      guard let range = rangeOfPaddedURL else {
        return nil
      }
      let nextURL = item.substring(with: range)
      // strip off the < and >;
      let start = nextURL.index(range.lowerBound, offsetBy: 1)
      let end = nextURL.index(range.upperBound, offsetBy: -2)
      let trimmedRange = start ..< end
      return nextURL.substring(with: trimmedRange)
    }
    return nil
  }
}
