import Foundation
import UIKit

final class MemoListViewController: UIViewController {
    private var memos = [Memo]()
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
            self?.updateTableView()
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
    
    private func showMemoDetailVC(for indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: StoryboardNames.memoDetail, bundle: nil)
        guard let memoDetailViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.memoDetailViewController) as? MemoDetailViewController else { return }
        memoDetailViewController.memo = memos[indexPath.row]
        memoDetailViewController.memoService = self.memoService
        // 遷移先でtabbarを非表示にする処理
        memoDetailViewController.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(memoDetailViewController, animated: true)
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

    
    private func updateTableView() {
        DispatchQueue.main.async {
            self.memoListTableView.reloadData()
            self.activityIndicator.stopAnimating()
            self.refreshControl.endRefreshing()
        }
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
        
            cell.configure(name: memos[indexPath.row].name, time: memos[indexPath.row].latestUpdate)
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
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        // 更新されたテキストが15文字を超えていないかチェック
        return updatedText.count <= NumericValues.maxMemonameLength
    }
}
