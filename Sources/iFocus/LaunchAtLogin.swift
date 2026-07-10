import AppKit
import Foundation
import ServiceManagement

/// Login-item registration via `SMAppService` (macOS 13+).
///
/// Best results when the app lives in `/Applications` as a real `.app` bundle.
/// Development/`swift run` builds cannot reliably register.
enum LaunchAtLogin {
    enum Status: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case notFound
        case unsupported
    }
    
    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        case .notRegistered:
            return .disabled
        @unknown default:
            return .disabled
        }
    }
    
    static var isEnabled: Bool {
        status == .enabled
    }
    
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> (ok: Bool, message: String?) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    return (true, nil)
                }
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    return (true, "已请求登录启动，请在「系统设置 → 通用 → 登录项」中允许 iFocus。")
                }
                return (true, "已开启：登录时启动 iFocus")
            } else {
                try SMAppService.mainApp.unregister()
                return (true, "已关闭登录时启动")
            }
        } catch {
            return (false, "设置失败：\(error.localizedDescription)。请将 iFocus 放到「应用程序」文件夹后再试。")
        }
    }
    
    static func openLoginItemsSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems"
        ]
        for value in urls {
            if let url = URL(string: value), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
