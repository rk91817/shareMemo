import UIKit

final class ResetPasswordViewController: UIViewController {
    @IBOutlet private weak var emailTextField: UITextField!
    @IBOutlet private weak var sendEmailButton: UIButton!
    @IBOutlet private weak var returnToLoginVCButton: UIButton!
    var memoService: MemoService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        setupButtonLayout()
        setupTextFields()
        setupKeyboardTypes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    @objc private func tappedsendEmailButton() {
        sendPasswordReset()
    }
    
    @objc private func tappedreturnToLoginVCButton() {
        self.navigationController?.popViewController(animated: true)
    }
    // パスワード再設定のメールを送信する処理
    private func sendPasswordReset() {
        guard let email = emailTextField.text else { return }
        memoService?.sendPasswordReset(email: email) { [weak self] result in
            switch result {
            case .success:
                self?.showSendEmailAlert(email: email)
            case .failure: break
            }
        }
    }
    
    private func showSendEmailAlert(email: String) {
        let alertController = UIAlertController(
            title: AlertTitle.completeSendEmail,
            message: AppError.sentEmail(email).message,
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: AlertActionTitle.ok, style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alertController, animated: true)
    }
    
    @objc private func editingChanged(_ textField: UITextField) {
        guard let emailText = emailTextField.text, !emailText.isEmpty
        else {
            sendEmailButton.isEnabled = false
            return
        }
        sendEmailButton.isEnabled = true
    }

    
    private func setupButtons() {
        sendEmailButton.addTarget(self, action: #selector(tappedsendEmailButton), for: .touchUpInside)
        returnToLoginVCButton.addTarget(self, action: #selector(tappedreturnToLoginVCButton), for: .touchUpInside)
        sendEmailButton.isEnabled = false
    }
    
    private func setupButtonLayout() {
        sendEmailButton.layer.cornerRadius = NumericValues.cornerRadius
        sendEmailButton.clipsToBounds = true
    }
    
    private func setupTextFields() {
        emailTextField.delegate = self
        emailTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    }
    
    private func setupKeyboardTypes() {
        emailTextField.keyboardType = .asciiCapable
    }
}

extension ResetPasswordViewController: UITextFieldDelegate {
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
