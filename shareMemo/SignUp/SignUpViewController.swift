import Foundation
import UIKit

final class SignUpViewController: UIViewController {
    @IBOutlet private weak var profileImageButton: UIButton!
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var usernameTextField: UITextField!
    @IBOutlet private weak var registerButton: UIButton!
    @IBOutlet private weak var signUpedUserButton: UIButton!
    var memoService: MemoService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        setupKeyboardTypes()
        setupButtons()
        setupButtonLayout()
        setupNavigationController()
        setupProfileImageButtonDefaultImage()
        makeProfileImageButtonRound()
    }
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        makeProfileImageButtonRound()
    }
    
    @objc private func tappedProfileImageButton() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        self.present(imagePickerController, animated: true, completion: nil)
    }
    // 登録決定ボタン　プロフィール画像やメアドなどを保存する処理
    @objc private func tappedRegisterButton() {
        if let image = profileImageButton.imageView?.image {
            uploadProfileImage(image: image)
        } else {
            // プロフィール画像が設定されていない場合、nilを渡して登録を進める
            createUserToFirestore(profileImageUrl: nil)
        }
    }
    // ログイン画面に遷移させる処理
    @objc private func alreadySignUpedUserButton() {
        showSignInVC()
    }
    
    private func createUserToFirestore(profileImageUrl: String?) {
        guard let email = emailTextField.text, let password = passwordTextField.text, let username = usernameTextField.text else { return }
        memoService?.createUser(email: email, password: password) { [weak self] result in
            switch result {
            case .failure: break
            case .success(var user):
                user.username = username
                user.profileImageUrl = profileImageUrl ?? URLs.profileImage
                // Firestoreにユーザーデータを保存
                self?.memoService?.setUserData(user: user) { result in
                    switch result {
                    case .success:
                        self?.showTabbarVC()
                    case .failure: break
                    }
                }
            }
        }
    }
    
    private func uploadProfileImage(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: NumericValues.compressionQuality) else { return }
        
        memoService?.uploadImage(imageData: imageData) { [weak self] result in
            switch result {
            case .success(let urlString):
                self?.createUserToFirestore(profileImageUrl: urlString)
            case .failure: break
            }
        }
    }
    
    private func showSignInVC() {
        let storyboard = UIStoryboard(name: StoryboardNames.SignIn, bundle: nil)
        guard let loginViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.SignInViewController) as? SignInViewController else { return }
        loginViewController.memoService = self.memoService
        self.navigationController?.pushViewController(loginViewController, animated: true)
    }
    
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
        usernameTextField.delegate = self
    }
    
    private func setupKeyboardTypes() {
        emailTextField.keyboardType = .asciiCapable
        passwordTextField.keyboardType = .asciiCapable
    }

    private func setupButtons() {
        profileImageButton.addTarget(self, action: #selector(tappedProfileImageButton), for: .touchUpInside )
        registerButton.addTarget(self, action: #selector(tappedRegisterButton), for: .touchUpInside)
        signUpedUserButton.addTarget(self, action: #selector(alreadySignUpedUserButton), for: .touchUpInside)
        registerButton.isEnabled = false
    }
    
    private func setupButtonLayout() {
        registerButton.layer.cornerRadius = NumericValues.cornerRadius
        registerButton.clipsToBounds = true
    }

    private func setupNavigationController() {
        navigationController?.navigationBar.isHidden = true
    }
    // プロフィール画像ボタンにデフォルトの背景画像を設定する
    private func setupProfileImageButtonDefaultImage() {
        if let defaultImage = UIImage(named: ImageNames.defaultImage) {
            profileImageButton.setBackgroundImage(defaultImage, for: .normal)
        }
    }
    // プロフィール画像ボタンを円形にする
    private func makeProfileImageButtonRound() {
        profileImageButton.layer.cornerRadius = profileImageButton.bounds.width / NumericValues.circleShapeDivisor
        profileImageButton.clipsToBounds = true
        
        // ボタンの周囲に線を引く
        profileImageButton.layer.borderWidth = NumericValues.profileImageButtonBorderWidth
        profileImageButton.layer.borderColor = UIColor.gray.cgColor
    }
}

extension SignUpViewController: UITextFieldDelegate {
    // TextFieldが全て埋まっていてパスワードが6文字以上の場合登録ボタンを有効化
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard let email = emailTextField.text,
              let password = passwordTextField.text,
              let username = usernameTextField.text else {
                  registerButton.isEnabled = false
                  return
              }
        registerButton.isEnabled = !email.isEmpty && password.count >= NumericValues.minPasswordLength && !username.isEmpty
    }
        
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Deleteキーによる文字の削除を許可
        if string.isEmpty { return true }
        // ユーザーネームの入力は八文字以下に制限
        if textField == usernameTextField {
            let newLength = (textField.text?.count ?? 0) - range.length + string.count
            return newLength <= NumericValues.maxUsernameLength
        }
        // emailTextFieldとpasswordTextFieldに適用する正規表現パターン
        let emailAndPasswordPattern = RegexPatterns.emailAndPassword
        if string.range(of: emailAndPasswordPattern, options: .regularExpression) != nil {
            return true
        }
        // 上記の条件にマッチしない場合は入力を許可しない
        return false
    }
}

extension SignUpViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let editImage = info[.editedImage] as? UIImage {
            profileImageButton.setImage(editImage.withRenderingMode(.alwaysOriginal), for: .normal)
        } else if let originalImage = info[.originalImage] as? UIImage {
            profileImageButton.setImage(originalImage.withRenderingMode(.alwaysOriginal), for: .normal)
        }
        profileImageButton.setTitle("", for: .normal)
        profileImageButton.imageView?.contentMode = .scaleAspectFill
        profileImageButton.contentHorizontalAlignment = .fill
        profileImageButton.contentVerticalAlignment = .fill
        profileImageButton.clipsToBounds = true
        dismiss(animated: true, completion: nil)
    }
}
