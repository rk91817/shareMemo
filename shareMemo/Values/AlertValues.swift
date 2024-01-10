enum AlertTitle {
    static let completeSendEmail = "メール送信完了"
    static let inputError = "入力エラー"
    static let fetchDataError = "データの取得に失敗"
    static let saveDataError = "データの保存に失敗"
    static let updateDataError = "データの更新に失敗"
    static let searchResult = "検索結果"
    static let confirmation = "確認"
}

enum AlertActionTitle {
    static let ok = "OK"
    static let cancel = "キャンセル"
    static let retry = "再試行"
    static let delete = "削除"
}

enum AppError: Error {
    case sentEmail(String)
    case userNotLogin
    case alreadyExists
    case notFound
    case userNotFound
    case selfAddNotAllowed
    case userFound(String)
    case userMismatch
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case wrongPassword
    case confirmDeleteAccount
    case failedDownloadUrl
    case someError
    
    var message: String {
        switch self {
        case .sentEmail(let email):
            return "\(email)にパスワード再設定のメールを送信しました"
        case .userNotLogin:
            return "ユーザー情報が取得できません"
        case .alreadyExists:
            return "既に存在しています"
        case .notFound:
            return "データが存在しません"
        case .userNotFound:
            return "入力したメールアドレスのユーザーは存在しません"
        case .selfAddNotAllowed:
            return "自分自身を友達に追加することはできません"
        case .userFound(let username):
            return "\(username)さんが見つかりました。追加しますか？"
        case .userMismatch:
            return "ログイン中のユーザーと一致しません"
        case .invalidEmail:
            return "メールアドレスが無効な形式です。"
        case .emailAlreadyInUse:
            return "このメールアドレスはすでに使われています。"
        case .weakPassword:
            return "パスワードは6文字以上入力して下さい。"
        case .wrongPassword:
            return "パスワードが間違っています"
        case .confirmDeleteAccount:
            return "本当にアカウントを削除しますか？"
        case .failedDownloadUrl:
            return "画像のダウンロードURLの取得に失敗しました。"
        case .someError:
            return "予期せぬエラーが発生しました"
        }
    }
}
