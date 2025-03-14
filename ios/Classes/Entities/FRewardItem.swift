class FRewardItem : NSObject {
    init(amount: NSNumber, type: String) {
            self.amount = amount
            self.type = type
        }

    let amount : NSNumber
    let type: String
}
