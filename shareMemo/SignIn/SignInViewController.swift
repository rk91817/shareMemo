import Foundation
import UIKit

final class SignInViewController: UIViewController {
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var loginButton: UIButton!
    @IBOutlet private weak var dontHaveAccountButton: UIButton!
    @IBOutlet private weak var resetPasswordButton: UIButton!
    
    var memoService: MemoService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMemoServiceErrorHandlers(memoService: memoService)
        setupButtons()
        setupButtonLayout()
        setupTextFields()
        setupKeyboardTypes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    @objc private func tappedLoginButton() {
        signIn()
    }

    @objc private func tappedDontHaveAccountButton() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc private func tappedResetPasswordButton() {
        showResetPasswordVC()
    }
    
    private func signIn() {
        guard let email = emailTextField.text, let password = passwordTextField.text else { return }
        memoService?.signIn(email: email, password: password) { result in
            switch result {
            case .success:
                self.showTabbarVC()
            case .failure: break
            }
        }
    }
    // パスワードリセット画面に遷移する処理
    private func showResetPasswordVC() {
        let storyboard = UIStoryboard(name: StoryboardNames.resetPassword, bundle: nil)
        guard let resetPasswordVC = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.resetPasswordViewController) as? ResetPasswordViewController else { return }
        resetPasswordVC.memoService = self.memoService
        self.navigationController?.pushViewController(resetPasswordVC, animated: true)
    }
    
    // tabbar画面に遷移する処理
    private func showTabbarVC() {
        let storyboard = UIStoryboard(name: StoryboardNames.mainTab, bundle: nil)
        guard let tabBarViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.tabBarController) as? UITabBarController else { return }
        
        if let viewControllers = tabBarViewController.viewControllers {
            for navigationController in viewControllers as? [UINavigationController] ?? [] {
                if let memoListVC = navigationController.viewControllers.first as? MemoListViewController {
                    memoListVC.memoService = memoService
                } else if let friendListVC = navigationController.viewControllers.first as? FriendListViewController {
                    friendListVC.memoService = memoService
                }
            }
        }
        tabBarViewController.modalPresentationStyle = .fullScreen // これがないと上部に前のviewが残る
        self.present(tabBarViewController, animated: true, completion: nil)
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
    
    private func setupButtons() {
        loginButton.addTarget(self, action: #selector(tappedLoginButton), for: .touchUpInside)
        dontHaveAccountButton.addTarget(self, action: #selector(tappedDontHaveAccountButton), for: .touchUpInside)
        resetPasswordButton.addTarget(self, action: #selector(tappedResetPasswordButton), for: .touchUpInside)
        loginButton.isEnabled = false
    }
    
    private func setupButtonLayout() {
        loginButton.layer.cornerRadius = NumericValues.cornerRadius
        loginButton.clipsToBounds = true
    }

    @objc private func editingChanged(_ textField: UITextField) {
        guard
            let email = emailTextField.text, !email.isEmpty,
            let password = passwordTextField.text, !password.isEmpty && password.count >= NumericValues.minPasswordLength
        else {
            loginButton.isEnabled = false
            return
        }
        loginButton.isEnabled = true
    }
}

extension SignInViewController: UITextFieldDelegate {
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
