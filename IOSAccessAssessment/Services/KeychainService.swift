//
//  KeychainService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 08.11.2024.
//

import Foundation
import Security

import Foundation
import Security

final class KeychainService {

    func setValue(_ value: String, for key: String) {
        guard let encodedValue = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: encodedValue
            ]
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = encodedValue
            status = SecItemAdd(newItem as CFDictionary, nil)
        }
        
        if status != errSecSuccess {
            print("Keychain setValue error: \(status)")
        }
    }
    
    func getValue(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }
        
        guard status == errSecSuccess else {
            return nil
        }
        
        if let data = queryResult as? Data, let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return nil
    }
    
    func removeValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("Keychain removeValue error: \(status)")
        }
    }
    
    func setDate(_ date: Date, for key: String) {
        let dateString = dateToString(date)
        setValue(dateString, for: key)
    }
    
    func getDate(for key: String) -> Date? {
        guard let dateString = getValue(for: key) else { return nil }
        return stringToDate(dateString)
    }
    
    func isTokenValid() -> Bool {
        guard let _ = getValue(for: "accessToken") else {
            return false
        }
        
        if let expirationDate = getDate(for: "expirationDate"), expirationDate > Date() {
            return true
        }
        
        return false
    }

    private func dateToString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    
    private func stringToDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
}
