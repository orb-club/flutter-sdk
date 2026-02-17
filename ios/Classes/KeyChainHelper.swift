import Foundation

final class KeychainHelper {
    static let standard = KeychainHelper()
    private init() {}
    
    func save(
        _ data: Data,
        service: String,
        account: String,
        saveToCloud: Bool
    ) -> OSStatus {
        if saveToCloud {
            return saveToiCloudKeychain(data, service: service, account: account)
        } else {
            return saveToDeviceKeychain(data, service: service, account: account)
        }
    }
    
    func saveToiCloudKeychain(
        _ data: Data,
        service: String,
        account: String
    ) -> OSStatus {
        let query = [
            kSecValueData: data,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: true,
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
        ] as CFDictionary

        // Add data in query to keychain
        let status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            // Item already exist, thus update it.
            let updateQuery = [
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecAttrSynchronizable: true,
                kSecClass: kSecClassGenericPassword,
            ] as CFDictionary

            let attributesToUpdate = [kSecValueData: data] as CFDictionary

            // Update existing item
            return SecItemUpdate(updateQuery, attributesToUpdate)
        }

        return status
    }
    
    func saveToDeviceKeychain(
        _ data: Data,
        service: String,
        account: String
    ) -> OSStatus {
        let query = [
            kSecValueData: data,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ] as CFDictionary

        // Add data in query to keychain
        let status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            // Item already exist, thus update it.
            let updateQuery = [
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecClass: kSecClassGenericPassword,
            ] as CFDictionary

            let attributesToUpdate = [kSecValueData: data] as CFDictionary

            // Update existing item
            return SecItemUpdate(updateQuery, attributesToUpdate)
        }

        return status
    }
    
    func read(service: String, account: String) -> FlutterKeychainResponse {
        let iCloudResult = readFromiCloudKeychain(service: service, account: account)

        // Return success data and migrate to device keychain for reliability.
        if iCloudResult.status == errSecSuccess, let data = iCloudResult.value {
            // Migrate iCloud wallet to device keychain for reliability.
            // Only remove from iCloud after confirming device save succeeded.
            let deviceSaveStatus = saveToDeviceKeychain(data, service: service, account: account)
            if deviceSaveStatus == noErr {
                deleteFromiCloudKeychain(service: service, account: account)
            }
            return iCloudResult
        }

        // Return error data, skip "not found" state.
        if iCloudResult.status != errSecItemNotFound {
            return iCloudResult
        }

        // If not found in iCloud, look at the device keychain.
        let localData = readFromDeviceKeychain(service: service, account: account)
        return localData
    }
    
    func readFromDeviceKeychain(service: String, account: String) -> FlutterKeychainResponse {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true,
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        if status == errSecItemNotFound {
            return FlutterKeychainResponse(status: errSecItemNotFound, value: nil)
        }
        
        guard status == errSecSuccess, let data = result as? Data else {
            return FlutterKeychainResponse(status: status, value: nil)
        }
        
        return FlutterKeychainResponse(status: status, value: data)
    }
    
    func readFromiCloudKeychain(service: String, account: String) -> FlutterKeychainResponse {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: true,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true,
        ] as CFDictionary
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        
        if status == errSecItemNotFound {
            return FlutterKeychainResponse(status: errSecItemNotFound, value: nil)
        }
        
        guard status == errSecSuccess, let data = result as? Data else {
            return FlutterKeychainResponse(status: status, value: nil)
        }
        
        return FlutterKeychainResponse(status: status, value: data)
    }
    
    func delete(service: String, account: String) {
        deleteFromDeviceKeychain(service: service, account: account)
        deleteFromiCloudKeychain(service: service, account: account)
    }
    
    func deleteFromDeviceKeychain(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary
        
        // Delete item from keychain
        SecItemDelete(query)
    }
    
    func deleteFromiCloudKeychain(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: true,
            kSecClass: kSecClassGenericPassword,
        ] as CFDictionary
        
        // Delete item from keychain
        SecItemDelete(query)
    }
}

public struct FlutterKeychainResponse {
    var status: OSStatus
    var value: Data?
}