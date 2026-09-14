import Foundation

class FAdError : NSObject {
    init(code: NSNumber, message: String) {
            self.code = code
            self.message = message
        }
    convenience init(error: NSError) {
        self.init(code: NSNumber(value: error.code), message: error.localizedDescription)
    }

    let code : NSNumber
    let message: String
}
