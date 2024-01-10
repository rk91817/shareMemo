import Foundation

enum StoryboardNames {
    static let signUp = "SignUp"
    static let SignIn = "SignIn"
    static let resetPassword = "ResetPassword"
    static let mainTab = "MainTab"
    static let createMemo = "CreateMemo"
    static let memoDetail = "MemoDetail"
    static let configuration = "Configuration"
    static let searchUser = "SearchUser"
    static let deleteUser = "DeleteUser"
}

enum VCIdentifiers {
    static let signUpViewController = "SignUpViewController"
    static let SignInViewController = "SignInViewController"
    static let resetPasswordViewController = "ResetPasswordViewController"
    static let tabBarController = "TabBarController"
    static let createMemoViewController = "CreateMemoViewController"
    static let memoDetailViewController = "MemoDetailViewController"
    static let configurationViewController = "ConfigurationViewController"
    static let searchUserViewController = "SearchUserViewController"
    static let deleteUserViewController = "DeleteUserViewController"
}

enum NavigationBarTitle {
    static let friend = "フレンド"
    static let memo = "メモ"
}

enum BarButtonIcons {
    static let gear = "gear"
    static let search = "magnifyingglass"
    static let back = "chevron.left"
    static let refresh = "arrow.triangle.2.circlepath"
}

enum URLs {
    static let profileImage = "https://knsoza1.com/wp-content/uploads/2020/07/70b3dd52350bf605f1bb4078ef79c9b9.png"
    static let privacyPolicy =  "https://sites.google.com/view/sharememo/%E3%83%9B%E3%83%BC%E3%83%A0"
}

enum ImageNames {
    static let defaultImage = "defaultImage"
    static let noImage = "noImage"
}

enum TextValues {
    static let fetching = "取得中..."
    static let empty = ""
    static let requestForMemoNameInput = "さんとのメモ名を入力してください"
}

enum RegexPatterns {
    static let emailAndPassword = "^[a-zA-Z0-9@._-]+$"
    static let firebaseUid = "^[a-zA-Z0-9]+$"
}

enum NumericValues {
    static let tableViewHeaderHeight = 1.0
    static let memoListTableViewDivisior = 8.0 // テーブルビューを八等分する数値
    static let friendListtableViewDivisior = 8.0 // テーブルビューを八等分する数値
    static let circleShapeDivisor  = 2.0
    static let cornerRadius: CGFloat = 5
    static let profileImageButtonBorderWidth = 0.5
    static let MediumTransparency = 0.5
    static let minPasswordLength = 6
    static let maxUsernameLength = 8
    static let maxMemonameLength = 15
    static let compressionQuality = 0.3
    static let memoTextUpdateInterval = 1.5
    static let minimumPressDuration = 0.5
    static let allowableMovement: CGFloat = 10
}
