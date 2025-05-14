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
    
    var nodesWithAttributes: [String: [String : String]] = [:]
    var waysWithAttributes: [String: [String : String]] = [:]

    func parse(data: Data) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if currentElement == "node" {
            nodesWithAttributes[elementName] = attributeDict
        }
        if currentElement == "way" {
            waysWithAttributes[elementName] = attributeDict
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
