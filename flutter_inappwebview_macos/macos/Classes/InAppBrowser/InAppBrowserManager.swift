//
//  InAppBrowserManager.swift
//  flutter_inappwebview
//
//  Created by Lorenzo Pichilli on 18/12/2019.
//

import FlutterMacOS
import AppKit
import WebKit
import Foundation
import AVFoundation

public class InAppBrowserManager: ChannelDelegate {
    static let METHOD_CHANNEL_NAME = "com.pichillilorenzo/flutter_inappbrowser"
    static let WEBVIEW_STORYBOARD = "WebView"
    static let WEBVIEW_STORYBOARD_CONTROLLER_ID = "viewController"
    static let NAV_STORYBOARD_CONTROLLER_ID = "navController"
    var plugin: InAppWebViewFlutterPlugin?
    
    init(plugin: InAppWebViewFlutterPlugin) {
        super.init(channel: FlutterMethodChannel(name: InAppBrowserManager.METHOD_CHANNEL_NAME, binaryMessenger: plugin.registrar.messenger))
        self.plugin = plugin
    }
    
    public override func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary

        switch call.method {
            case "open":
                open(arguments: arguments!)
                result(true)
                break
            case "openWithSystemBrowser":
                let url = arguments!["url"] as! String
                openWithSystemBrowser(url: url, result: result)
                break
            default:
                result(FlutterMethodNotImplemented)
                break
        }
    }
    
    public func open(arguments: NSDictionary) {
        let id = arguments["id"] as! String
        let urlRequest = arguments["urlRequest"] as? [String:Any?]
        let assetFilePath = arguments["assetFilePath"] as? String
        let data = arguments["data"] as? String
        let mimeType = arguments["mimeType"] as? String
        let encoding = arguments["encoding"] as? String
        let baseUrl = arguments["baseUrl"] as? String
        let settings = arguments["settings"] as! [String: Any?]
        let windowId = arguments["windowId"] as? Int64
        let initialUserScripts = arguments["initialUserScripts"] as? [[String: Any]]
        let menuItems = arguments["menuItems"] as! [[String: Any?]]
        let viewId = arguments["viewId"] as? Int64

        let browserSettings = InAppBrowserSettings()
        let _ = browserSettings.parse(settings: settings)

        let webViewSettings = InAppWebViewSettings()
        let _ = webViewSettings.parse(settings: settings)

        let webViewController = InAppBrowserWebViewController()
        webViewController.plugin = plugin
        webViewController.browserSettings = browserSettings
        webViewController.webViewSettings = webViewSettings

        webViewController.id = id
        webViewController.initialUrlRequest = urlRequest != nil ? URLRequest.init(fromPluginMap: urlRequest!) : nil
        webViewController.initialFile = assetFilePath
        webViewController.initialData = data
        webViewController.initialMimeType = mimeType
        webViewController.initialEncoding = encoding
        webViewController.initialBaseUrl = baseUrl
        webViewController.windowId = windowId
        webViewController.initialUserScripts = initialUserScripts ?? []
        webViewController.isHidden = browserSettings.hidden

        let window = InAppBrowserWindow(contentViewController: webViewController)
        window.browserSettings = browserSettings
        window.contentViewController = webViewController
        for menuItem in menuItems {
            window.menuItems.append(InAppBrowserMenuItem.fromMap(map: menuItem)!)
        }
        window.prepare()

        // Resolve Flutter view by id if provided (multi-view), else fall back to main window
        // Note: macOS FlutterPluginRegistrar doesn't have multi-view API yet (GetViewById),
        // so for now we use registrar.view (single view) or fall back to main window
        var parentWindow: NSWindow? = NSApplication.shared.mainWindow
        if let plugin = plugin {
            if let flutterView = plugin.registrar.view {
                parentWindow = flutterView.window ?? NSApplication.shared.mainWindow
            }
        }
        // TODO: Once macOS FlutterPluginRegistrar supports multi-view API,
        // use viewId to get specific view: plugin.registrar.view(withIdentifier: viewId)

        if #available(macOS 10.12, *), browserSettings.windowType == .tabbed {
            parentWindow?.addTabbedWindow(window, ordered: .above)
        } else if browserSettings.windowType == .child {
            parentWindow?.addChildWindow(window, ordered: .above)
        } else {
            window.windowController?.showWindow(self)
        }

        window.makeKeyAndOrderFront(self)
        if browserSettings.hidden {
            // https://github.com/pichillilorenzo/flutter_inappwebview/issues/1939
            // without calling first window.makeKeyAndOrderFront(self)
            // window.hide() would deallocate and dispose the InAppBrowserWindow
            window.hide()
            parentWindow?.makeKeyAndOrderFront(self)
        }
    }
    
    public func openWithSystemBrowser(url: String, result: @escaping FlutterResult) {
        let absoluteUrl = URL(string: url)!.absoluteURL
        if !NSWorkspace.shared.open(absoluteUrl) {
            result(FlutterError(code: "InAppBrowserManager", message: url + " cannot be opened!", details: nil))
            return
        }
        result(true)
    }
    
    public override func dispose() {
        super.dispose()
        plugin = nil
    }
    
    deinit {
        dispose()
    }
}
