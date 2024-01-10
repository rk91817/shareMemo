import Foundation
import UIKit

final class MemoDetailViewController: UIViewController {
    @IBOutlet private weak var memoTextView: UITextView!
    var memo: Memo?
    var memoService: MemoService?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        listeningToMemo()
        setUpTextView()
        setupNavigationBarAppearance()
        setUpViewColor()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super .viewWillAppear(animated)
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        memoService?.stopListeningMemoUpdates()
        saveMemoIfNeeded()
    }
    // メモコレクションを監視する処理
    private func listeningToMemo() {
        guard let memoId = memo?.id else { return }
        memoService?.startListeningMemoUpdates(memoId: memoId) { [weak self] result in
            switch result {
            case .success(let latestMemo):
                self?.updateTextViewContent(memo: latestMemo)
            case .failure: break
            }
        }
    }
    // 受け取ったメモを元にviewを更新
    private func updateTextViewContent(memo: Memo) {
        memoTextView.text = memo.content
    }
    // 最後にテキストを入力し終わってから1.5秒経ったらメモ保存処理を呼び出す処理
    private func debounceTextUpdate() {
        guard let text = memoTextView.text, let memo = memo else { return }
        memoService?.debounceTextUpdate(memo: memo, text: text)
    }
    private func saveMemoIfNeeded() {
        guard let text = memoTextView.text, let memo = memo else { return }
        // テキストに変更がなければ早期リターン
        guard memoTextView.text != memo.content else { return }
        memoService?.saveMemo(memo: memo, content: text)
    }

    private func setUpTextView() {
        memoTextView.delegate = self
        setUpTextViewContent()
    }
    
    private func setUpTextViewContent() {
        guard let content = memo?.content else { return }
        memoTextView.text = content
    }
    // NavigationBar以外の背景色の設定
    private func setUpViewColor() {
        self.view.backgroundColor = UIColor.customPeach
    }

    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.customPeach
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.shadowColor = .clear
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.setToolbarHidden(true, animated: true)
    }
}

extension MemoDetailViewController: UITextViewDelegate {
    // textViewが変更される度にdebounceTextUpdate()を呼び出す
    func textViewDidChange(_ textView: UITextView) {
        debounceTextUpdate()
    }
}
