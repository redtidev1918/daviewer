import Cocoa
import FlutterMacOS
import Network
import WebKit

class MainFlutterWindow: NSWindow {
  private var webViewProxyChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "daviewer/webview_proxy",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard #available(macOS 14.0, *) else {
        result(false)
        return
      }
      switch call.method {
      case "setProxy":
        guard
          let arguments = call.arguments as? [String: Any],
          let host = arguments["host"] as? String,
          let port = arguments["port"] as? Int,
          let endpointPort = NWEndpoint.Port(rawValue: UInt16(port))
        else {
          result(FlutterError(code: "invalid_proxy", message: "Invalid proxy address", details: nil))
          return
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: endpointPort)
        var proxy = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
        proxy.allowFailover = false
        WKWebsiteDataStore.default().proxyConfigurations = [proxy]
        WKWebsiteDataStore.nonPersistent().proxyConfigurations = [proxy]
        result(true)
      case "clearProxy":
        WKWebsiteDataStore.default().proxyConfigurations = []
        WKWebsiteDataStore.nonPersistent().proxyConfigurations = []
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    webViewProxyChannel = channel

    super.awakeFromNib()
  }
}
