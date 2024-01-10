import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage

final class FirestoreManager {
    private var memoListener: ListenerRegistration?
    
    func startListeningMemoUpdates(memoId: String, completion: @escaping (Result<Memo, Error>) -> Void) {
        let listener = Firestore.firestore().collection(Collections.memos).document(memoId).addSnapshotListener { documentSnapshot, error in
            if let snapshot = documentSnapshot {
                switch self.convertToModel(from: snapshot) as Result<Memo, Error> {
                case .success(var memo):
                    let documentId = snapshot.documentID
                    memo.id = documentId
                    completion(.success(memo))
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            } else if let error = error {
                completion(.failure(error))
            }
        }
        // Listenerの参照を保持しておく
        memoListener = listener
    }
    
    // リスナーを停止するメソッド
    func stopListeningMemoUpdates() {
        memoListener?.remove()
        memoListener = nil
    }
    private func convertToModel<T: Decodable>(from documentSnapshot: DocumentSnapshot) -> Result<T, Error> {
        do {
            let model = try documentSnapshot.data(as: T.self)
            return .success(model)
        } catch {
            return .failure(error)
        }
    }
    
    func getUser(documentId: String, completion: @escaping (Result<User, Error>) -> Void) {
        Firestore.firestore().collection(Collections.users).document(documentId).getDocument { documentSnapshot, error in
            if let documentSnapshot = documentSnapshot, documentSnapshot.exists {
                let result: Result<User, Error> = self.convertToModel(from: documentSnapshot)
                switch result {
                case .success(var user):
                    user.uid = documentSnapshot.documentID
                    completion(.success(user))
                case .failure(let error):
                    completion(.failure(error))
                }
            } else {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(AppError.notFound))
                }
            }
        }
    }
    
    // ユーザー情報を保存する処理
    func saveUser(user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = user.uid else {
            completion(.failure(AppError.someError))
            return
        }
        
        do {
            let userData = try Firestore.Encoder().encode(user)
            Firestore.firestore().collection(Collections.users).document(uid).setData(userData) { err in
                if let err = err {
                    completion(.failure(err))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func deleteUser(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Firestore.firestore().collection(Collections.users).document(uid).delete { err in
            if let err = err {
                completion(.failure(err))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func getFriends(currentUserUid: String, completion: @escaping (Result<[Friend], Error>) -> Void) {
        var friendsArray: [Friend] = []
        Firestore.firestore().collection(Collections.users).document(currentUserUid).collection(Collections.friends).getDocuments { friendsSnapShots, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            
            friendsSnapShots?.documents.forEach { snapshot in
                let result: Result<Friend, Error> = self.convertToModel(from: snapshot)
                switch result {
                case .success(let friend):
                    friendsArray.append(friend)
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            }
            completion(.success(friendsArray))
        }
    }
    
    // フレンドを相互に追加するためにcreateFriendを2回呼び出す処理
    func createFriendToBothUsers(currentUser: User, newFriend: User, completion: @escaping (Result<Void, Error>) -> Void) {
        createFriend(friend: newFriend, toUser: currentUser) { result in
            switch result {
            case .success:
                self.createFriend(friend: currentUser, toUser: newFriend, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    // フレンドコレクションにユーザーを追加する処理
    private func createFriend(friend: User, toUser user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userUid = user.uid, let friendUid = friend.uid else {
            completion(.failure(AppError.notFound))
            return
        }
        let friend = Friend(uid: friendUid)
        do {
            let friendData = try Firestore.Encoder().encode(friend)
            Firestore.firestore().collection(Collections.users).document(userUid).collection(Collections.friends).document(friendUid).setData(friendData) { err in
                if let err = err {
                    completion(.failure(err))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func getAllMemos(completion: @escaping (Result<[Memo], Error>) -> Void) {
        var memoArray: [Memo] = []
        let memoRef = Firestore.firestore().collection(Collections.memos)
        memoRef.getDocuments { memosnapshots, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            
            memosnapshots?.documents.forEach { snapshot in
                let result: Result<Memo, Error> = self.convertToModel(from: snapshot)
                switch result {
                case .success(var memo):
                    let documentId = snapshot.documentID
                    memo.id = documentId
                    memoArray.append(memo)
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            }
            completion(.success(memoArray))
        }
    }
    
    // どちらか一方のUIDが含まれているメモを取得
    func getMemosIncludingAnyOfUserUids(_ uids: [String], completion: @escaping (Result<[Memo], Error>) -> Void) {
        var memoArray: [Memo] = []
        let memoRef = Firestore.firestore().collection(Collections.memos).whereField(Fields.members, arrayContainsAny: uids)
        memoRef.getDocuments { snapshots, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            
            snapshots?.documents.forEach { snapshot in
                switch self.convertToModel(from: snapshot) as Result<Memo, Error> {
                case .success(var memo):
                    let documentId = snapshot.documentID
                    memo.id = documentId
                    memoArray.append(memo)
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            }
            completion(.success(memoArray))
        }
    }
    
    // 更新順に並び替えたメモを取得
    func getLatestMemosForCurrentUser(uid: String, completion: @escaping (Result<[Memo], Error>) -> Void) {
        var memoArray: [Memo] = []
        let memoRef = Firestore.firestore().collection(Collections.memos)
            .whereField(Fields.members, arrayContains: uid)
            .order(by: Fields.latestUpdate, descending: true)
        
        memoRef.getDocuments { snapshots, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            
            snapshots?.documents.forEach { snapshot in
                switch self.convertToModel(from: snapshot) as Result<Memo, Error> {
                case .success(var memo):
                    let documentId = snapshot.documentID
                    memo.id = documentId
                    memoArray.append(memo)
                case .failure(let error):
                    completion(.failure(error))
                    return
                }
            }
            completion(.success(memoArray))
        }
    }
    
    func saveMemo(memo: Memo, content: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let memoId = memo.id else {
            completion(.failure(AppError.someError))
            return
        }
        let newMemo = Memo(name: memo.name, members: memo.members, content: content, latestUpdate: Date())
        let memoRef = Firestore.firestore().collection(Collections.memos).document(memoId)
        do {
            try memoRef.setData(from: newMemo)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    func createMemo(friendUid: String, memoName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUserUid = Auth.auth().currentUser?.uid else {
            completion(.failure(AppError.someError))
            return
        }
        var memo = Memo(name: memoName, members: [currentUserUid, friendUid], content: "", latestUpdate: Date())
        let ref = Firestore.firestore().collection(Collections.memos).document()
            memo.id = ref.documentID
        
        do {
            try ref.setData(from: memo)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // プロフィール画像をストレージに保存する処理
    func saveProfileImageToStorage(imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        let fileName = NSUUID().uuidString
        let storageRef = Storage.storage().reference().child(StorageDirectories.profileImages).child(fileName)
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            self.downloadURLFromStorage(reference: storageRef, completion: completion)
        }
    }
    
    private func downloadURLFromStorage(reference: StorageReference, completion: @escaping (Result<String, Error>) -> Void) {
        reference.downloadURL { url, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            guard let urlString = url?.absoluteString else {
                completion(.failure(AppError.failedDownloadUrl))
                return
            }
            completion(.success(urlString))
        }
    }
    
    // プロフィール画像をfirestoreに更新する処理
    func updateProfileImage(uid: String, profileImageUrl: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let ref = Firestore.firestore().collection(Collections.users).document(uid)
        ref.updateData([Fields.profileImageUrl: profileImageUrl]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func getErrorMessageAndTitle(error: NSError) -> (title: String, message: String) {
        var title = AlertTitle.confirmation
        var message = AppError.someError.message
        if let error = error as? FirestoreErrorCode {
            switch error.code {
            case .alreadyExists:
                title = AlertTitle.searchResult
                message = AppError.alreadyExists.message
            case .notFound:
                title = AlertTitle.fetchDataError
                message = AppError.notFound.message
            default: break
            }
        }
        return (title, message)
    }
}
