import Flutter
import UIKit
import Foundation


public class FlutterSdkPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "rly_network_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = FlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "getBundleId":
            result(RlyNetworkMobileSdk().getBundleId())
        case "generateNewMnemonic":
            result(RlyNetworkMobileSdk().generateMnemonic())
        case "getPrivateKeyFromMnemonic":
            if let arguments = call.arguments as? [String: Any], let data = arguments["mnemonic"] as? String {
                result(RlyNetworkMobileSdk().getPrivateKeyFromMnemonic(data))
            } else {
                // Handle the case where 'arguments' or 'data' is nil
                // You might want to return an error or a default value here.
            }
        case "getMnemonic":
            let mnemonic = RlyNetworkMobileSdk().getMnemonic()
            handleResponse(mnemonic, result, responseMapper: mapDataToString)
        case "mnemonicBackedUpToCloud":
            let cloudMnemonic = RlyNetworkMobileSdk().mnemonicBackedUpToCloud()
            handleResponse(cloudMnemonic, result, responseMapper: mapDataToBoolean)
        case "deleteMnemonic":
            result(RlyNetworkMobileSdk().deleteMnemonic())
        case "deleteCloudMnemonic":
            result(RlyNetworkMobileSdk().deleteCloudMnemonic())
        case "saveMnemonic":
            if let arguments = call.arguments as? [String: Any],
               let mnemonicToSave = arguments["mnemonic"] as? String,
               let saveToCloud = arguments["saveToCloud"] as? Bool,
               let rejectOnCloudSaveFailure = arguments["rejectOnCloudSaveFailure"] as? Bool {
                result(RlyNetworkMobileSdk().saveMnemonic(mnemonicToSave, saveToCloud: saveToCloud, rejectOnCloudSaveFailure: rejectOnCloudSaveFailure))
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func mapDataToString(_ data: Data?) -> String? {
        guard let data = data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func mapDataToBoolean(_ data: Data?) -> Bool {
        return data != nil
    }

    private func handleResponse(_ response: FlutterKeychainResponse, _ result: @escaping FlutterResult, responseMapper: ((Data?) -> Any?)? = nil) {
        let status = response.status
        if status != noErr {
            handleErrorResponse(status, result)
        } else {
            if let responseMapper = responseMapper {
                result(responseMapper(response.value))
            } else {
                result(response.value)
            }
        }
    }
    
    private func handleErrorResponse(_ status: OSStatus, _ result: @escaping FlutterResult) {
        let errorMessage: String
        if #available(iOS 11.3, *) {
            if let errMsg = SecCopyErrorMessageString(status, nil) {
                errorMessage = "Code: \(status), Message: \(errMsg)"
            } else {
                errorMessage = "Unknown security result code: \(status)"
            }
        } else {
            errorMessage = "Unknown security result code: \(status)"
        }
        result(FlutterError(code: "Unexpected security result code", message: errorMessage as String, details: status))
    }
}
