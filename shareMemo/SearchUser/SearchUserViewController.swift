import Foundation
import UIKit

final class SearchUserViewController: UIViewController {
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var searchButton: UIButton!
    
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

    @objc private func tappedSearchbutton() {
        proposeFriendAddition()
    }
    // verifyUserに成功したらフレンド追加確認アラートを呼び出す処理
    private func proposeFriendAddition() {
        verifyUser { [weak self] result in
            switch result {
            case .success(let user):
                self?.presentAddFriendAlert(user: user)
            case .failure: break
            }
        }
    }
    // 検索したIDがフレンド追加できるか確認する処理
    private func verifyUser(completion: @escaping (Result<User, Error>) -> Void) {
        guard let documentId = searchTextField.text else { return }
        Task {
            do {
                let user = try await self.memoService?.getUser(documentId: documentId)
                guard let user = user else { return }
                memoService?.checkIfUserIsAlreadyFriend(user: user) { [weak self] result in
                    switch result {
                    case .success(let exists):
                        if exists {
                            self?.memoService?.errorDidOccur?(AppError.alreadyExists, .none)
                        } else {
                            completion(.success(user))
                        }
                    case .failure: break
                    }
                }
            } catch {
                // memoService.getUser関数内でエラー処理しているのでここでは書かない
                print("error", error)
            }
        }
    }

    // フレンドを追加するか確認のアラートを出す処理
    private func presentAddFriendAlert (user: User) {
        let alertController = UIAlertController(
            title: AlertTitle.searchResult,
            message: AppError.userFound(user.username).message,
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: AlertActionTitle.cancel, style: .cancel))
        alertController.addAction(UIAlertAction(title: AlertActionTitle.ok, style: .default) { [weak self] _ in
            self?.addFriend(user: user)
        })
        
        present(alertController, animated: true)
    }
    // memoServiceのフレンド追加処理を呼び出す処理
    private func addFriend(user: User) {
        self.memoService?.validateFriendRequest(user: user) { [weak self] result in
            switch result {
            case .success:
                self?.navigationController?.popViewController(animated: true)
            case .failure: break
            }
        }
    }

    @objc private func editingChanged(_ textField: UITextField) {
        if let text = searchTextField.text, !text.isEmpty {
            searchButton.isEnabled = true
            searchButton.backgroundColor = UIColor.white
        } else {
            searchButton.isEnabled = false
            searchButton.backgroundColor = UIColor.lightGray
        }
    }

    @objc private func tappedDismissButton () {
        self.navigationController?.popViewController(animated: true)
    }
    
    private func setupButton() {
        let dismissBarButton = UIBarButtonItem(image: UIImage(systemName: BarButtonIcons.back)!, style: .plain, target: self, action: #selector(tappedDismissButton))
        navigationItem.leftBarButtonItem = dismissBarButton
        searchButton.addTarget(self, action: #selector(tappedSearchbutton), for: .touchUpInside )
        searchButton.isEnabled = false
        searchButton.backgroundColor = UIColor.lightGray
    }
    
    private func setupButtonLayout() {
        searchButton.layer.cornerRadius = NumericValues.cornerRadius
        searchButton.clipsToBounds = true
    }
    
    private func setupTextFields() {
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    }
  
    private func setupKeyboardTypes() {
        searchTextField.keyboardType = .asciiCapable
    }
}

extension SearchUserViewController: UITextFieldDelegate {
    // textFieldに入力できる文字を指定
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Deleteキーによる文字の削除を許可
        if string.isEmpty { return true }
        // 入力が正規表現にマッチするかチェック
        let regexPatterns = RegexPatterns.firebaseUid
        if string.range(of: regexPatterns, options: .regularExpression) != nil {
            return true
        }
        // 上記の条件にマッチしない場合は入力を許可しない
        return false
    }
}
