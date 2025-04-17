import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    private let service = "CourtRoomSimService"
    private let account = "OpenAIApiKey"
    
    func saveAPIKey(_ key: String) {
        let keyData = Data(key.utf8)
        let query: [String: Any] = [
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecClass as String: kSecClassGenericPassword
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = keyData
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            fatalError("Keychain: Unable to save API key (code \(status)).")
        }
    }
    
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let keyData = result as? Data,
           let key = String(data: keyData, encoding: .utf8) {
            return key
        }
        return nil
    }
}
