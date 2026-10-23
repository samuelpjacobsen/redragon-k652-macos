import Foundation

extension Array where Element == UInt8 {
    public var hexString: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
