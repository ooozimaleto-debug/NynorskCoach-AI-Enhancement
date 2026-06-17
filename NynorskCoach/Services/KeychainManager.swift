//
//  KeychainManager.swift
//  NynorskCoach
//
//  Secure storage for API keys and sensitive data
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let serviceName = "com.zimaleto.NynorskCoach"
    
    // MARK: - Save
    
    /// Сохранить значение в Keychain
    @discardableResult
    func saveKey(_ value: String, forAccount account: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ Keychain: Failed to encode value")
            return false
        }
        
        // Удалить старое значение если есть
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Сохранить новое
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Keychain: Saved key for \(account)")
            return true
        } else {
            print("❌ Keychain: Failed to save key - Error: \(status)")
            return false
        }
    }
    
    // MARK: - Get
    
    /// Получить значение из Keychain
    func getKey(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        if status == errSecItemNotFound {
            print("ℹ️  Keychain: No key found for \(account)")
        } else {
            print("❌ Keychain: Error retrieving key - Error: \(status)")
        }
        
        return nil
    }
    
    // MARK: - Delete
    
    /// Удалить значение из Keychain
    func deleteKey(forAccount account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            print("✅ Keychain: Deleted key for \(account)")
            return true
        } else {
            print("❌ Keychain: Failed to delete key")
            return false
        }
    }
    
    // MARK: - Clear All
    
    /// Удалить ВСЕ ключи приложения (для отладки)
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        SecItemDelete(query as CFDictionary)
        print("✅ Keychain: Cleared all keys")
    }
}
