import Foundation
import UIKit

final class CreateMemoViewController: UIViewController {
    @IBOutlet private weak var friendNameLabel: UILabel!
    @IBOutlet private weak var memoNameTextField: UITextField!
    @IBOutlet private weak var createButton: UIButton!
    var friend: Friend?
    var memoService: MemoService?
    weak var delegate: MemoDetailNavigationDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFriendNameLabel()
        setupMemoNameTextField()
        setupCreateButton()
        setupButtonLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    @objc private func tappedCreateButton() {
        createMemo()
    }
    
    private func createMemo() {
        guard let friend = self.friend else { return }
        // フレンドのUidを取得する処理
        memoService?.getFriendUidIfNoMemoExists(friendUid: friend.uid) { [weak self] result in
            switch result {
            case .success(let friendUid):
                self?.createMemoToFirestore(friendUid: friendUid)
            case .failure: break
            }
        }
    }
        
    private func createMemoToFirestore(friendUid: String) {
        guard let text = memoNameTextField.text else { return }
        
        memoService?.createMemo(friendUid: friendUid, memoName: text) { [weak self] result in
            switch result {
            case .success:
                // 一度フレンドリストに画面を戻してshowMemoDetailを呼び出す
                self?.dismiss(animated: true, completion: nil)
                self?.delegate?.showMemoDetail(friendUid: friendUid)
            case .failure: break
            }
        }
    }
    
    private func setupFriendNameLabel() {
        guard let friendId = friend?.uid else { return }
        memoService?.getUser(documentId: friendId) { [weak self] result in
            switch result {
            case .success(let user):
                self?.friendNameLabel.text = "\(user.username)\(TextValues.requestForMemoNameInput)"
            case .failure: break
            }
        }
    }
    
    private func setupMemoNameTextField() {
        memoNameTextField.delegate = self
        memoNameTextField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
    }
    
    private func setupCreateButton() {
        createButton.addTarget(self, action: #selector(tappedCreateButton), for: .touchUpInside )
        createButton.isEnabled = false
    }
    
    private func setupButtonLayout() {
        createButton.layer.cornerRadius = NumericValues.cornerRadius
        createButton.clipsToBounds = true
    }
    
    @objc private func editingChanged(_ textField: UITextField) {
        guard let memoName = memoNameTextField.text, !memoName.isEmpty
        else {
            createButton.isEnabled = false
            return
        }
        createButton.isEnabled = true
    }
}

extension CreateMemoViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 現在のテキストの長さと変更される範囲の長さ、新しい文字列の長さを計算
        let currentTextLength = textField.text?.count ?? 0
        let newLength = currentTextLength - range.length + string.count

        // 新しいテキストの長さが15文字以下かどうか確認
        return newLength <= NumericValues.maxMemonameLength
    }
}
