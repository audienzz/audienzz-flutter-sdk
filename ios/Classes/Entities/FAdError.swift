class FAdError : NSObject {
    init(code: NSNumber, message: String) {
            self.code = code
            self.message = message
        }
    let code : NSNumber
    let message: String
}
