// Copyright 2019 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Discovery
import Commander

extension Discovery.Method {
  func parametersTypeDeclaration(resource : String, method : String) -> String {
    var s = ""
    s.addLine()
    if let parameters = parameters {
      s.addLine(indent:2, "public struct " + parametersTypeName(resource:resource, method:method) + " : Parameterizable {")
      for p in parameters.sorted(by:  { $0.key < $1.key }) {
        s.addLine(indent:4, "public var " + p.key.fieldName() + " : " + p.value.schemaType() + "?")
      }
      s.addLine(indent:4, "public func queryParameters() -> [String] {")
      s.addLine(indent:6, "return [" +
        parameters.sorted(by: { $0.key < $1.key })
          .filter { if let location = $0.value.location { return location == "query" } else {return false}}
          .map { return "\"" + $0.key + "\"" }
          .joined(separator: ",")
        + "]")
      s.addLine(indent:4, "}")
      s.addLine(indent:4, "public func pathParameters() -> [String] {")
      s.addLine(indent:6, "return [" +
        parameters.sorted(by: { $0.key < $1.key })
          .filter { if let location = $0.value.location { return location == "path" } else {return false}}
          .map { return "\"" + $0.key + "\"" }
          .joined(separator: ",")
        + "]")
      s.addLine(indent:4, "}")
      s.addLine(indent:2, "}")
    }
    return s
  }
}

extension Discovery.Resource {
  func generateCallersForMethods(name: String) -> String {
    var s = ""
    if let methods = self.methods {
      for m in methods.sorted(by:  { $0.key < $1.key }) {
        if m.value.hasParameters() {
          s += m.value.parametersTypeDeclaration(resource:name, method:m.key)
        }
        let methodName = name + "_" + m.key
        s.addLine()
        s.addLine(indent:2, "public func \(methodName.fieldName()) (")
        if m.value.hasRequest() {
          s.addLine(indent:4, "request: \(m.value.requestTypeName()),")
        }
        if m.value.hasParameters() {
          s.addLine(indent:4, "parameters: \(m.value.parametersTypeName(resource:name, method:m.key)),")
        }
        if m.value.hasResponse() {
          s.addLine(indent:4, "completion: @escaping (\(m.value.responseTypeName())?, Error?) -> ()) throws {")
        } else {
          s.addLine(indent:4, "completion: @escaping (Error?) -> ()) throws {")
        }
        s.addLine(indent:6, "try perform(")
        s.addLine(indent:8, "method: \"\(m.value.httpMethod!)\",")
        var path = ""
        if m.value.path != nil {
          path = m.value.path!
        }
        s.addLine(indent:8, "path: \"\(path)\",")
        if m.value.hasRequest() {
          s.addLine(indent:8, "request: request,")
        }
        if m.value.hasParameters() {
          s.addLine(indent:8, "parameters: parameters,")
        }
        s.addLine(indent:8, "completion: completion)")
        s.addLine(indent:2, "}")
      }
    }
    if let resources = self.resources {
      for r in resources.sorted(by:  { $0.key < $1.key }) {
        s += r.value.generateCallersForMethods(name: name + "_" + r.key)
      }
    }
    return s
  }
}

extension Discovery.Service {
  func generateClientLibrary() -> String {
    guard let schemas = schemas else {
      return ""
    }
    var s = Discovery.License
    s.addLine()
    for i in
      ["Foundation",
       "OAuth2",
       "GoogleAPIRuntime"] {
        s.addLine("import " + i)
    }
    s.addLine()
    s.addLine("public class \(self.className()) : Service {")
    s.addLine()
    s.addLine(indent:2, "init(tokenProvider: TokenProvider) throws {")
    s.addLine(indent:4, "try super.init(tokenProvider, \"\(self.baseUrl)\")")
    s.addLine(indent:2, "}")
    s.addLine()
    s.addLine(indent:2, "public class Object : Codable {}")
    for schema in schemas.sorted(by:  { $0.key < $1.key }) {
      switch schema.value.type {
      case "object":
        s.addLine()
        s.addLine(indent:2, "public struct \(schema.key) : Codable {")
        if let properties = schema.value.properties {
          for p in properties.sorted(by: { $0.key < $1.key }) {
            s.addLine(indent:4, "public var `\(p.key.fieldName())` : \(p.value.schemaType())?")
          }
        }
        s.addLine(indent:2, "}")
      case "array":
        s.addLine()
        if let itemsSchema = schema.value.items {
          if let itemType = itemsSchema.type {
            switch itemType {
            case "object":
              s.addLine(indent:2, "public typealias \(schema.key.fieldName()) = [\(schema.key)Item]")
              s.addLine()
              s.addLine(indent:2, "public struct \(schema.key)Item : Codable {")
              if let properties = itemsSchema.properties {
                for p in properties.sorted(by: { $0.key < $1.key }) {
                  s.addLine(indent:4, "public var `\(p.key)` : \(p.value.schemaType())?")
                }
              }
              s.addLine("}")
            default:
              s.addLine("ERROR-UNHANDLED-ARRAY-TYPE \(itemType)")
            }
          }
        }
      case "any":
        s.addLine()
        s.addLine(indent:2, "typealias " + schema.key + " = JSONAny")
      default:
        s.addLine("ERROR-UNHANDLED-SCHEMA-VALUE-TYPE \(schema.key) \(String(describing:schema.value.type))")
      }
    }
    
    if let resources = resources {
      for r in resources.sorted(by:  { $0.key < $1.key }) {
        s += r.value.generateCallersForMethods(name: r.key)
      }
    }
    s.addLine("}")
    return s
  }
}

func makeDirectory(name : String) throws {
  try FileManager.default.createDirectory(atPath: name,
                                          withIntermediateDirectories: true,
                                          attributes: nil)
}


let main = command(
  Argument<String>("API", description: "API description in Google API Discovery Service format"),
  Option<String>("output", default: ".", description: "output directory")
) { (filename:String, output:String) in
  let data = try Data(contentsOf: URL(fileURLWithPath: filename))
  let decoder = JSONDecoder()
  do {
    let service = try decoder.decode(Service.self, from: data)
    let code = service.generateClientLibrary()
    let outputFilename = output + "/" + service.className() + ".swift"
    try makeDirectory(name: output)
    try code.write(to: URL(fileURLWithPath: outputFilename),
                   atomically: true,
                   encoding: String.Encoding.utf8)
  } catch {
    print("error \(error)\n")
  }
}

main.run()
