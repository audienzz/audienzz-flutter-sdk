import Flutter

class FAdViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> any FlutterPlatformView {
        guard let adId = args as? NSNumber,
              let view = manager.ad(for: adId) as? FlutterPlatformView else {
                  let reason = String(
                    format: "Could not find an ad with id: %@. Was this ad already disposed?",
                    String(describing: args)
                  )
                  print(reason)
                  return FNativeView(frame: frame, viewIdentifier: viewId, arguments: args)
                  
              }
        
        return view
    }
    
    private let manager: AdInstanceManager
    
    init(manager: AdInstanceManager) {
        self.manager = manager
        super.init()
    }
    
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) {
        _view = UIView()
        super.init()
        // iOS views can be created here
        createNativeView(view: _view)
    }
    
    func view() -> UIView {
        return _view
    }
    
    func createNativeView(view _view: UIView){
        _view.backgroundColor = UIColor.blue
        let nativeLabel = UILabel()
        nativeLabel.text = "Error Happened"
        nativeLabel.textColor = UIColor.white
        nativeLabel.textAlignment = .center
        nativeLabel.frame = CGRect(x: 0, y: 0, width: 180, height: 48.0)
        _view.addSubview(nativeLabel)
    }
}
