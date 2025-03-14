struct FVideoBitrate {
    init(min: NSNumber, max: NSNumber) {
        self.min = min
        self.max = max
    }
    
    let min: NSNumber
    let max: NSNumber
}
