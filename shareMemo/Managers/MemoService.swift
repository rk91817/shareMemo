import Foundation

enum ManagerType {
    case firestore
    case auth
    case none
}

final class MemoService {
    private let firestoreManager: FirestoreManager
    private let firebaseAuthManager: FirebaseAuthManager
    
    init(firestoreManager: FirestoreManager, authService: FirebaseAuthManager) {
        self.firestoreManager = firestoreManager
        self.firebaseAuthManager = authService
    }
    
    private var friends: [Friend] = [] {
        didSet { friendsDidChange?(friends) }
    }
    
    private var memos: [Memo] = [] {
        didSet { memosDidChange?(memos) }
    }
    
    var friendsDidChange: (([Friend]) -> Void)?
    var memosDidChange: (([Memo]) -> Void)?
    var errorDidOccur: ((Error, ManagerType) -> Void)?
    var currentUid: String? { return firebaseAuthManager.currentUid }
    var debounceTimer: Timer?
    
    func getUser(documentId: String, completion: @escaping (Result<User, Error>) -> Void) {
        firestoreManager.getUser(documentId: documentId) { result in
            switch result {
            case .success(let user):
                completion(.success(user))
            case .failure(let error):
                if let error = error as? AppError {
                    self.errorDidOccur?(error, .none)
                } else {
                    self.errorDidOccur?(error, .firestore)
                }
            }
        }
    }
    // async/awaitバージョンのgetUser
    func getUser(documentId: String) async throws -> User {
        // withCheckedThrowingContinuationを使って非同期処理をラップする
        return try await withCheckedThrowingContinuation { continuation in
            // クロージャベースのgetUserを呼び出す
            firestoreManager.getUser(documentId: documentId) { result in
                // Result型の結果に基づいてcontinuationを再開する
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    if let error = error as? AppError {
                        self.errorDidOccur?(error, .none)
                    } else {
                        self.errorDidOccur?(error, .firestore)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // ユーザー情報を保存するための関数
    func setUserData(user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreManager.saveUser(user: user) {result in
            switch result {
            case .success(let user):
                completion(.success(user))
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    func deleteUserFromFirestore(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreManager.deleteUser(uid: uid, completion: completion)
    }
    
    func fetchAllFriends(currentUserUid: String) {
        guard let currentUserUid = currentUid else {
            self.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        firestoreManager.getFriends(currentUserUid: currentUserUid) { [weak self] result in
            switch result {
            case .success(let fetchedFriends):
                self?.friends = fetchedFriends
            case .failure(let error):
                self?.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    private func addFriendToBothUsers(currentUser: User, newFriend: User, completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreManager.createFriendToBothUsers(currentUser: currentUser, newFriend: newFriend, completion: completion)
    }

    // ユーザーが既に自分のフレンドコレクションに存在するか確認する処理
    func checkIfUserIsAlreadyFriend (user: User, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let currentUserUid = currentUid else {
            self.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        firestoreManager.getFriends(currentUserUid: currentUserUid) { result in
            switch result {
            case .success(let friends):
                let exists = friends.contains { $0.uid == user.uid }
                completion(.success(exists))
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    // フレンド追加のためのバリデーションをし、フレンド追加処理を呼び出す処理
    func validateFriendRequest(user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserUid = currentUid else {
            self.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        guard user.uid != currentUserUid else {
            self.errorDidOccur?(AppError.selfAddNotAllowed, .none)
            return
        }
        self.firestoreManager.getUser(documentId: currentUserUid) { userResult in
            switch userResult {
            case .success(let currentUser):
                self.addFriendToBothUsers(currentUser: currentUser, newFriend: user) { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure(let error):
                        self.errorDidOccur?(error, .firestore)
                    }
                }
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    // 自分と相手のUIDを含むメモがなければフレンドのUIDを返す処理
    func getFriendUidIfNoMemoExists(friendUid: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let currentUserUid = currentUid else {
            self.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        firestoreManager.getAllMemos { result in
            switch result {
            case .success(let memos):
                let filteredMemos = self.filterMemos(uids: [currentUserUid, friendUid], from: memos)
                if filteredMemos.isEmpty {
                    completion(.success(friendUid))
                }
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    func startListeningMemoUpdates(memoId: String, completion: @escaping (Result<Memo, Error>) -> Void) {
        firestoreManager.startListeningMemoUpdates(memoId: memoId) { result in
            switch result {
            case .success(let memo):
                completion(.success(memo))
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    func stopListeningMemoUpdates() {
        firestoreManager.stopListeningMemoUpdates()
    }
    // 最後にテキストを入力し終わってから1.5秒経ったらメモ保存処理を呼び出す処理
    func debounceTextUpdate(memo: Memo, text: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: NumericValues.memoTextUpdateInterval, repeats: false) { [weak self] _ in
            self?.saveMemo(memo: memo, content: text)
        }
    }

    func createMemo(friendUid: String, memoName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        firestoreManager.createMemo(friendUid: friendUid, memoName: memoName) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                if let error = error as? AppError {
                    self.errorDidOccur?(error, .none)
                } else {
                    self.errorDidOccur?(error, .firestore)
                }
            }
        }
    }

    func saveMemo(memo: Memo, content: String) {
        firestoreManager.saveMemo(memo: memo, content: content) { result in
            switch result {
            case .success: break
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    // 現在のユーザーと相手のUIDを含むメモをフィルタリング
    private func filterMemos(uids: [String], from memos: [Memo]) -> [Memo] {
        return memos.filter { memo in
            uids.allSatisfy { memo.members.contains($0) }
        }
    }
    
    // 更新順に並び替えたメモを取得
    func getLatestMemos() {
        guard let currentUserUid = currentUid else {
            self.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        firestoreManager.getLatestMemosForCurrentUser(uid: currentUserUid) { result in
            switch result {
            case .success(let memos):
                self.memos = memos
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    // 現在のユーザーとフレンド両方のUIDが含まれているメモを取得
    func fetchSharedMemo(friendUid: String, completion: @escaping (Result<Memo?, Error>) -> Void) {
        guard let currentUserUid = currentUid else {
            self.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        firestoreManager.getMemosIncludingAnyOfUserUids([currentUserUid, friendUid]) { result in
            switch result {
            case .success(let memos):
                let filteredMemos = self.filterMemos(uids: [currentUserUid, friendUid], from: memos)
                let filteredMemo = filteredMemos.first
                completion(.success(filteredMemo))
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
    
    // 画像をFirebaseストレージにアップロードするための関数
    func uploadImage(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        firestoreManager.saveProfileImageToStorage(imageData: imageData) { result in
            switch result {
            case .success(let urlString):
                completion(.success((urlString)))
            case .failure(let error):
                if let error = error as? AppError {
                    self.errorDidOccur?(error, .none)
                } else {
                    self.errorDidOccur?(error, .firestore)
                }
            }
        }
    }
    
    func updateProfileImage(uid: String, imageUrl: String, completion: @escaping () -> Void) {
        firestoreManager.updateProfileImage(uid: uid, profileImageUrl: imageUrl) { result in
            switch result {
            case .success:
                completion()
            case .failure(let error):
                self.errorDidOccur?(error, .firestore)
            }
        }
    }
        
    func createUser(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        firebaseAuthManager.createUser(withEmail: email, password: password) {result in
            switch result {
            case .success(let user):
                completion(.success(user))
            case .failure(let error):
                print(error)
                self.errorDidOccur?(error, .auth)
            }
        }
    }

    func deleteUserFromAuth(completion: @escaping (Result<Void, Error>) -> Void) {
        firebaseAuthManager.deleteUser { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.errorDidOccur?(error, .auth)
            }
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Result<Void, NSError>) -> Void) {
        firebaseAuthManager.signIn(email: email, password: password) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.errorDidOccur?(error, .auth)
            }
        }
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        firebaseAuthManager.sendPasswordReset(email: email) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.errorDidOccur?(error, .auth)
            }
        }
    }

    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        firebaseAuthManager.logout { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.errorDidOccur?(error, .auth)
            }
        }
    }
    
    func reauthenticate(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        firebaseAuthManager.reauthenticate(email: email, password: password) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                self.errorDidOccur?(error, .auth)
            }
        }
    }
    
    func getErrorMessageAndTitle(error: NSError, managerType: ManagerType) -> (title: String, message: String) {
        var title: String
        var message: String
        
        switch managerType {
        case .firestore:
            let result = firestoreManager.getErrorMessageAndTitle(error: error)
            title = result.title
            message = result.message
        case .auth:
            let result = firebaseAuthManager.getErrorMessageAndTitle(error: error)
            title = result.title
            message = result.message
        case .none: // Firebaseに関連しないエラーの処理
            if let appError = error as? AppError {
                switch appError {
                case .userNotLogin: title = AlertTitle.fetchDataError
                case .notFound: title = AlertTitle.fetchDataError
                case .selfAddNotAllowed: title = AlertTitle.inputError
                case .alreadyExists: title = AlertTitle.searchResult
                case .failedDownloadUrl: title = AlertTitle.fetchDataError
                default: title = AlertTitle.confirmation
                }
                message = appError.message
            } else {
                title = AlertTitle.confirmation
                message = AppError.someError.message
            }
        }
        return (title, message)
    }
}
