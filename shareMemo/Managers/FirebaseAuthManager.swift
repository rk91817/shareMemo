import FirebaseAuth

final class FirebaseAuthManager {
    var currentUid: String? {
        return Auth.auth().currentUser?.uid
    }
    
    func createUser(withEmail email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { res, err in
            if let err = err {
                completion(.failure(err))
            } else if let user = res?.user {
                let newUser = User(uid: user.uid, email: email, username: "", createdAt: Date(), profileImageUrl: "", friend: nil)
                completion(.success(newUser))
            }
        }
    }
    
    func deleteUser(completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().currentUser?.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func reauthenticate(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        Auth.auth().currentUser?.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            switch error {
            case .none:
                completion(.success(()))
            case .some(let error):
                completion(.failure(error))
            }
        }
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print(error)
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    func getErrorMessageAndTitle(error: NSError) -> (title: String, message: String) {
        var title = AlertTitle.confirmation
        var message = AppError.someError.message
        
        if let error = error as? AuthErrorCode {
            switch error.code {
            case .invalidEmail:
                title = AlertTitle.inputError
                message = AppError.invalidEmail.message
            case .userMismatch:
                title = AlertTitle.confirmation
                message = AppError.userMismatch.message
            case .emailAlreadyInUse:
                title = AlertTitle.inputError
                message = AppError.emailAlreadyInUse.message
            case .weakPassword:
                title = AlertTitle.inputError
                message = AppError.weakPassword.message
            case .userNotFound:
                title = AlertTitle.inputError
                message = AppError.userNotFound.message
            case .wrongPassword:
                title = AlertTitle.inputError
                message = AppError.wrongPassword.message
            default: break
            }
        }
        return (title, message)
    }
}
