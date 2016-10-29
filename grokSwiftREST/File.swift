//
//  File.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-10-29.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import Foundation

class File {
  var filename: String?
  var raw_url: String?
  var content: String?
  
  required init?(json: [String: Any]) {
    self.filename = json["filename"] as? String
    self.raw_url = json["raw_url"] as? String
  }
  
  init?(aName: String?, aContent: String?) {
    self.filename = aName
    self.content = aContent
  }
}
