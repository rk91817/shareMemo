import Foundation
import UIKit

extension UIColor {
    static let customWhite = UIColor.rgb(red: 255, green: 255, blue: 255)
    static let customPeach = UIColor.rgb(red: 255, green: 255, blue: 235)
    static let customSkyBlue = UIColor.rgb(red: 105, green: 175, blue: 200)
    
    static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
        return self.init(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}
