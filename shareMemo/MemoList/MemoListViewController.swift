import Foundation
import UIKit

final class MemoListViewController: UIViewController {
    private var memos = [Memo]()
    private var memoAndFriendInfo: [(Memo, User)] = []// memoとメモ相手のフレンドのユーザー情報のタプル
    var memoService: MemoService?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let refreshControl = UIRefreshControl()
    @IBOutlet private var memoListTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupMemoServiceLatestMemosHandlers()
        setupActivityIndicator()
        setupRefreshControl()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchData()
        setupMemoServiceErrorHandlers(memoService: memoService)
        setupNavigationBar() // viewdidloadでセットするとメモに遷移してこの画面戻った時にnavbarの色がバグる
    }

    // memoServiceから通知を受け取った時の処理
    private func setupMemoServiceLatestMemosHandlers() {
        memoService?.memosDidChange = { [weak self] memos in
            self?.memos = memos
            Task {
                // メモ相手のフレンドのユーザー情報を取得する処理
                await self?.getFriendsDetails()
                DispatchQueue.main.async {
                    self?.updateTableView()
                }
            }
        }
    }
    // firestoreからメモデータを取得
    @objc private func fetchData() {
        // refreshControlがリフレッシュ中でない場合のみ、activityIndicatorを表示する
        if !self.refreshControl.isRefreshing {
            self.activityIndicator.startAnimating()
        }
        memoService?.getLatestMemos()
    }
    // メモ相手のフレンドのユーザー情報を並列で取得する処理
    private func getFriendsDetails() async {
        guard let memoService = memoService, let currentUid = memoService.currentUid else { return }
        do {
            try await withThrowingTaskGroup(of: (Memo, User).self) { group in
                for memo in self.memos {
                    // memo.members配列のうち自分ではない相手のUIDを取得
                    guard let friendUid = memo.members.first(where: { $0 != currentUid }) else { return }
                    group.addTask {
                        let userDetails = try await memoService.getUser(documentId: friendUid)
                        return (memo, userDetails)
                    }
                }
                // 各タスクの結果を受け取り、memoAndFriendInfoに格納
                for try await (memo, userDetails) in group {
                    self.memoAndFriendInfo.append((memo, userDetails))
                }
            }
        } catch {
            self.showErrorAlert(error: error, memoService: memoService, managerType: .firestore)
        }
    }
    
    private func showMemoDetailVC(for indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: StoryboardNames.memoDetail, bundle: nil)
        guard let memoDetailViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.memoDetailViewController) as? MemoDetailViewController else { return }
        memoDetailViewController.memo = memos[indexPath.row]
        memoDetailViewController.memoService = self.memoService
        // 遷移先でtabbarを非表示にする処理
        memoDetailViewController.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(memoDetailViewController, animated: true)
    }
    // メモ名を編集するためのアラートを表示する関数
    private func showEditNameAlert(initialName: String, completion: @escaping (String) -> Void) {
        let alertController = UIAlertController(title: AlertTitle.changeMemoName, message: TextValues.requestForChangeMemoNameInput, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.text = initialName
            textField.delegate = self
        }
        let saveAction = UIAlertAction(title: AlertActionTitle.save, style: .default) { _ in
            if let newName = alertController.textFields?.first?.text {
                completion(newName)
            }
        }
        alertController.addAction(saveAction)
        alertController.addAction(UIAlertAction(title: AlertActionTitle.cancel, style: .cancel, handler: nil))
        present(alertController, animated: true)
    }
    
    private func updateTableView() {
        DispatchQueue.main.async {
            self.memoListTableView.reloadData()
            self.activityIndicator.stopAnimating()
            self.refreshControl.endRefreshing()
        }
    }
    
    private func setupActivityIndicator() {
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(fetchData), for: .valueChanged)
        memoListTableView.refreshControl = refreshControl
    }
    
    private func setupTableView() {
        memoListTableView.delegate = self
        memoListTableView.dataSource = self
        memoListTableView.register(MemoListTableViewCell.nib, forCellReuseIdentifier: MemoListTableViewCell.identifier)
    }

    private func setUpTabBarColor() {
        if let tabBar = self.tabBarController?.tabBar {
            tabBar.backgroundColor = UIColor.customWhite
            tabBar.barTintColor = UIColor.customWhite
        }
    }
    
    private func setupNavigationBar() {
        self.navigationController?.navigationBar.barTintColor = UIColor.customWhite
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.customWhite
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationItem.title = NavigationBarTitle.memo
    }
}

extension MemoListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellHeight = tableView.frame.size.height / NumericValues.memoListTableViewDivisior
        return cellHeight
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return memos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = memoListTableView.dequeueReusableCell(withIdentifier: MemoListTableViewCell.identifier, for: indexPath) as? MemoListTableViewCell else { return UITableViewCell() }
        let indexPathMemo = memos[indexPath.row]
        // memoAndFriendInfoから、indexPath.row番目のmemoに対応するUser情報を探して取得
        let IndexPathFriendInfo = memoAndFriendInfo.first { memo, _ in
            memo.id == indexPathMemo.id
        }
        // メモ相手の名前を取得
        let friendName = IndexPathFriendInfo?.1.username ?? TextValues.empty
        cell.configure(memoName: indexPathMemo.name, friendName: friendName, time: indexPathMemo.latestUpdate)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        showMemoDetailVC(for: indexPath)
        memoListTableView.deselectRow(at: indexPath, animated: true)
    }
    // 右スワイプでメモの名前を変更する処理
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let changeAction = UIContextualAction(style: .normal, title: TextValues.changeName) { [weak self] _, _, completionHandler in
            guard let self = self else { return }
            let memo = self.memos[indexPath.row], memoName = memo.name
            self.showEditNameAlert(initialName: memoName) { newName in
                self.memoService?.updateMemoName(memo: memo, newName: newName) { newName in
                    self.memos[indexPath.row].name = newName
                    DispatchQueue.main.async {
                        tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
            }
            completionHandler(true)// セルのスワイプを閉じる
        }
        changeAction.backgroundColor = .lightGray
        let configuration = UISwipeActionsConfiguration(actions: [changeAction])
        configuration.performsFirstActionWithFullSwipe = false // フルスワイプを無効にする
        return configuration
    }
}

extension MemoListViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 現在のテキストの長さと変更される範囲の長さ、新しい文字列の長さを計算
        let currentTextLength = textField.text?.count ?? 0
        let newLength = currentTextLength - range.length + string.count
        // 新しいテキストの長さが15文字以下かどうか確認
        return newLength <= NumericValues.maxMemonameLength
    }
}
