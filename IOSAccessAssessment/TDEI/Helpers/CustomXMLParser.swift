//
//  CustomXMLParser.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/14/25.
//

import Foundation

class ChangesetXMLParser: NSObject, XMLParserDelegate {
    var currentElement = ""
    var parsedItems: [String] = []
    
    var nodesWithAttributes: [String: OSMResponseNode] = [:]
    var waysWithAttributes: [String: OSMResponseWay] = [:]

    func parse(data: Data) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
//        print("Start Element: \(elementName), Attributes: \(attributeDict)")
        currentElement = elementName
        
        if currentElement == "node"  {
            guard let oldId = attributeDict[APIConstants.AttributeKeys.oldId],
                  let newId = attributeDict[APIConstants.AttributeKeys.newId],
                  let newVersion = attributeDict[APIConstants.AttributeKeys.newVersion] else {
                return
            }
            nodesWithAttributes[oldId] = OSMResponseNode(
                oldId: oldId, newId: newId, newVersion: newVersion, attributeDict: attributeDict
            )
        }
        if currentElement == "way" {
            guard let oldId = attributeDict[APIConstants.AttributeKeys.oldId],
                  let newId = attributeDict[APIConstants.AttributeKeys.newId],
                  let newVersion = attributeDict[APIConstants.AttributeKeys.newVersion] else {
                return
            }
            waysWithAttributes[oldId] = OSMResponseWay(
                oldId: oldId, newId: newId, newVersion: newVersion, attributeDict: attributeDict
            )
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Handle or store the string for the current element
        parsedItems.append(string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        // You could update your model here
    }
}
