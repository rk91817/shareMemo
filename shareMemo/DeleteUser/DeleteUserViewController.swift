import Foundation
import UIKit

final class  DeleteUserViewController: UIViewController {
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var deleteUserButton: UIButton!
    
    var memoService: MemoService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButton()
        setupButtonLayout()
        setupTextFields()
        setupKeyboardTypes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    @objc private func didTapReauthButton() {
        reauthenticateUser()
    }
    // ユーザーの退会処理
    private func deleteUser() {
        guard let uid = self.memoService?.currentUid else { return }

        memoService?.deleteUserFromAuth { [weak self] result in
            switch result {
            case .failure: break
            case .success:
                self?.deleteUserFromFirestore(uid: uid)
            }
        }
    }

    private func deleteUserFromFirestore(uid: String) {
        memoService?.deleteUserFromFirestore(uid: uid) { [weak self] result in
            switch result {
            case .failure: break
            case .success:
                self?.showSignUpVC()
            }
        }
    }
    // ユーザーの再認証処理
    private func reauthenticateUser() {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            return
        }
        
        memoService?.reauthenticate(email: email, password: password) { [weak self] result in
            switch result {
            case .failure: break
            case .success:
                let deleteAction = UIAlertAction(title: AlertActionTitle.delete, style: .destructive) { _ in
                    self?.deleteUser()
                }
                let cancelAction = UIAlertAction(title: AlertActionTitle.cancel, style: .cancel)
                self?.showAlert(title: AlertTitle.confirmation, message: AppError.confirmDeleteAccount.message, actions: [deleteAction, cancelAction])
            }
        }
    }
    
    private func showSignUpVC() {
        let storyboard = UIStoryboard(name: StoryboardNames.signUp, bundle: nil)
        guard let signUpViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.signUpViewController) as? SignUpViewController else { return }
        signUpViewController.memoService = memoService
        self.navigationController?.pushViewController(signUpViewController, animated: true)
    }
    
    private func setupButton() {
        deleteUserButton.addTarget(self, action: #selector(didTapReauthButton), for: .touchUpInside)
        deleteUserButton.isEnabled = false
        deleteUserButton.backgroundColor = UIColor.lightGray
    }
    
    private func setupButtonLayout() {
        deleteUserButton.layer.cornerRadius = NumericValues.cornerRadius
        deleteUserButton.clipsToBounds = true
    }
    
    private func setupTextFields() {
        emailTextField.delegate = self
        passwordTextField.delegate = self
        emailTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    }
  
    private func setupKeyboardTypes() {
        emailTextField.keyboardType = .asciiCapable
        passwordTextField.keyboardType = .asciiCapable
    }

    @objc private func editingChanged(_ textField: UITextField) {
        guard
            let email = emailTextField.text, !email.isEmpty,
            let password = passwordTextField.text, !password.isEmpty && password.count >= NumericValues.minPasswordLength
        else {
            deleteUserButton.isEnabled = false
            deleteUserButton.backgroundColor = UIColor.lightGray
            return
        }
        deleteUserButton.isEnabled = true
        deleteUserButton.backgroundColor = UIColor.white
        deleteUserButton.tintColor = UIColor.red
    }
}

extension DeleteUserViewController: UITextFieldDelegate {
    // textFieldに入力できる文字を指定
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Deleteキーによる文字の削除を許可
        if string.isEmpty { return true }
        // 入力が正規表現にマッチするかチェック
        let emailAndPasswordPattern = RegexPatterns.emailAndPassword
        if string.range(of: emailAndPasswordPattern, options: .regularExpression) != nil {
            return true
        }
        // 上記の条件にマッチしない場合は入力を許可しない
        return false
    }
}
