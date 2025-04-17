// KeychainManager.swift
// CourtRoomSim

import Foundation
import Security

/// A simple wrapper around the iOS Keychain for storing/retrieving the OpenAI API key.
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "CourtRoomSim"
    private let account = "openAIKey"

    /// Save or update the API key in the Keychain.
    func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            // Item exists — update it
            let attributes: [CFString: Any] = [
                kSecValueData: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(updateStatus)
            }

        case errSecItemNotFound:
            // Item not found — add it
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }

        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    /// Retrieve the API key from the Keychain.
    func retrieveAPIKey() throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw KeychainError.noKey
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.invalidKeyData
        }
        return key
    }
}

/// Errors that can occur when interacting with the Keychain.
enum KeychainError: Error, LocalizedError {
    case noKey
    case invalidKeyData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noKey:
            return "No API key found in Keychain."
        case .invalidKeyData:
            return "The data retrieved from Keychain was invalid."
        case .unhandledStatus(let status):
            return "Keychain error (status: \(status))."
        }
    }
}
