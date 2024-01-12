import Foundation

struct Memo: Codable {
    var id: String?
    var name: String
    let members: [String]
    let content: String
    let latestUpdate: Date
}
