import Foundation

struct Memo: Codable {
    var id: String?
    let name: String
    let members: [String]
    let content: String
    let latestUpdate: Date
}
