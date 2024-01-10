import Foundation

struct User: Codable {
    var uid: String?
    private let email: String
    var username: String
    private  let createdAt: Date
    var profileImageUrl: String
    var friend: Friend?
    
    private enum CodingKeys: String, CodingKey {
        case uid, email, username, createdAt, profileImageUrl
    }
    
    init(uid: String? = nil, email: String, username: String, createdAt: Date, profileImageUrl: String, friend: Friend? = nil) {
        self.uid = uid
        self.email = email
        self.username = username
        self.createdAt = createdAt
        self.profileImageUrl = profileImageUrl
        self.friend = friend
    }
}
