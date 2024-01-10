import Foundation
import UIKit

// メモ詳細画面への遷移を管理するプロトコル
protocol MemoDetailNavigationDelegate: AnyObject {
    func showMemoDetail(friendUid: String)
}

private enum TransitionStyle {
    case push
    case present
}

final class FriendListViewController: UIViewController, MemoDetailNavigationDelegate {
    var memoService: MemoService?
    private var friends = [Friend]()
    private var friendsDetails: [String: User] = [:] // フレンドのuidとユーザー情報の辞書
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let refreshControl = UIRefreshControl()
    @IBOutlet private var friendListTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMemoServiceFriendsHandlers()
        setupActivityIndicator()
        setupTableView()
        setupNavigationBar()
        setupRefreshControl()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFriendsData()
        setupMemoServiceErrorHandlers(memoService: memoService)
        setupNavigationBarAppearance()
        setUpTabBarColor()
    }
        
    @objc private func tappedConfigurationButton() {
        showConfigurationVC()
    }
    
    @objc private func tappedAddFriendButton() {
        showSearchUserVC()
    }
    
    @objc private func refreshFriendList() {
        fetchFriendsData()
    }
    // memoServiceから通知を受け取った時の処理
    private func setupMemoServiceFriendsHandlers() {
        memoService?.friendsDidChange = { [weak self] newFriends in
            self?.friends = newFriends
            
            Task {
                await self?.getFriendsDetails()
                DispatchQueue.main.async {
                    self?.friendListTableView.reloadData()
                    self?.activityIndicator.stopAnimating()
                    self?.refreshControl.endRefreshing()
                }
            }
        }
    }
    
    private func fetchFriendsData() {
        // refreshControlがリフレッシュ中でない場合のみ、activityIndicatorを表示する
        if !self.refreshControl.isRefreshing {
            self.activityIndicator.startAnimating()
        }
        
        guard let currentUid = memoService?.currentUid else { return }
        memoService?.fetchAllFriends(currentUserUid: currentUid)
    }
    // フレンドのユーザー情報を並列で取得
    private func getFriendsDetails() async {
        guard let memoService = memoService else {return}
        do {
            var friendsDetails = [String: User]()
            // 非同期タスクグループを作成して並列でフレンドのユーザー情報を取得
            try await withThrowingTaskGroup(of: (String, User).self) { group in
                for friend in self.friends {
                    group.addTask {
                        let userDetails = try await memoService.getUser(documentId: friend.uid)
                        return (friend.uid, userDetails)
                    }
                }
                    // 各タスクの結果を受け取りfriendsDetails辞書に格納
                for try await (uid, userDetails) in group {
                    friendsDetails[uid] = userDetails
                }
            }
            // タスクが全て完了した後に、メインの辞書を更新
            self.friendsDetails = friendsDetails
        } catch {
            self.showErrorAlert(error: error, memoService: memoService, managerType: .firestore)
        }
    }
    // セルの設定
    private func configureCell(cell: FriendListTableViewCell, friendDetails: User) {
        cell.configure(name: friendDetails.username, profileImageUrl: friendDetails.profileImageUrl)
        cell.imageTappedClosure = { [weak self] in
            self?.displayFullImage(image: cell.currentImage())
        }
    }
    // プロフィール画像を拡大表示する処理
    private func displayFullImage(image: UIImage?) {
        guard let image = image else { return }
        let imageViewController = UIViewController()
        imageViewController.view.backgroundColor = UIColor.black
        // 画像を表示するUIImageViewを作成し、画像を設定
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = imageViewController.view.frame
        imageViewController.view.addSubview(imageView)
        // 画像がタップされたら閉じる処理をViewに追加
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullImage))
        imageViewController.view.addGestureRecognizer(tap)
        present(imageViewController, animated: true, completion: nil)
    }
    
    @objc private func dismissFullImage(_ sender: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // メモの詳細を取得する処理
    private func fetchMemoDetail(friendUid: String, completion: @escaping (Result<Memo?, Error>) -> Void) {
        guard let memoService = memoService else { return }
        memoService.fetchSharedMemo(friendUid: friendUid, completion: completion)
    }
    
    // デリゲートメソッド
    func showMemoDetail(friendUid: String) {
        fetchMemoDetail(friendUid: friendUid) { [weak self] result in
            guard let memoService = self?.memoService else { return }
            switch result {
            case .success(let memo):
                self?.showMemoDetailVC(memo: memo)
            case .failure(let error):
                self?.showErrorAlert(error: error, memoService: memoService, managerType: .firestore)
            }
        }
    }
    
    private func showCreateMemoVC(friend: Friend) {
        showViewController(transitionStyle: .present, storyboardName: StoryboardNames.createMemo, identifier: VCIdentifiers.createMemoViewController, friend: friend)
    }
    
    private func showMemoDetailVC(memo: Memo?) {
        showViewController(transitionStyle: .push, storyboardName: StoryboardNames.memoDetail, identifier: VCIdentifiers.memoDetailViewController, memo: memo)
    }

    private func showConfigurationVC() {
        showViewController(transitionStyle: .push, storyboardName: StoryboardNames.configuration, identifier: VCIdentifiers.configurationViewController)
    }

    private func showSearchUserVC() {
        showViewController(transitionStyle: .push, storyboardName: StoryboardNames.searchUser, identifier: VCIdentifiers.searchUserViewController)
    }
    
    // VCに応じた画面遷移処理
    private func showViewController(transitionStyle: TransitionStyle, storyboardName: String, identifier: String, memo: Memo? = nil, friend: Friend? = nil) {
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: identifier)
        if let createMemoViewController = viewController as? CreateMemoViewController {
            createMemoViewController.friend = friend
            createMemoViewController.memoService = self.memoService
            createMemoViewController.delegate = self
        } else if let memoDetailViewController = viewController as? MemoDetailViewController {
            memoDetailViewController.memo = memo
            memoDetailViewController.memoService = self.memoService
        } else if let searchUserViewController = viewController as? SearchUserViewController {
            searchUserViewController.memoService = self.memoService
        } else if let configurationViewController = viewController as? ConfigurationViewController {
            configurationViewController.memoService = self.memoService
        }
        
        viewController.hidesBottomBarWhenPushed = true
        
        switch transitionStyle {
        case .push:
            self.navigationController?.pushViewController(viewController, animated: true)
        case .present:
            viewController.modalPresentationStyle = .pageSheet
            self.present(viewController, animated: true)
        }
    }
    
    private func setupActivityIndicator() {
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }
    
    private func setupRefreshControl() {
            refreshControl.addTarget(self, action: #selector(refreshFriendList), for: .valueChanged)
            friendListTableView.refreshControl = refreshControl
        }
    
    private func setupTableView() {
        friendListTableView.delegate = self
        friendListTableView.dataSource = self
        friendListTableView.register(FriendListTableViewCell.nib, forCellReuseIdentifier: FriendListTableViewCell.identifier)
    }
    
    private func setUpTabBarColor() {
        if let tabBar = self.tabBarController?.tabBar {
            tabBar.backgroundColor = UIColor.customWhite
            tabBar.barTintColor = UIColor.customWhite
        }
    }

    private func setupNavigationBar() {
        let configurationBarButton = UIBarButtonItem(image: UIImage(systemName: BarButtonIcons.gear)!, style: .plain, target: self, action: #selector(tappedConfigurationButton))
        navigationItem.leftBarButtonItem = configurationBarButton
        let addFriendBarButton = UIBarButtonItem(image: UIImage(systemName: BarButtonIcons.search)!, style: .plain, target: self, action: #selector(tappedAddFriendButton))
        navigationItem.rightBarButtonItem = addFriendBarButton
        navigationItem.title = NavigationBarTitle.friend
        navigationController?.isToolbarHidden = true
    }
    
    // navigationbarのcolorの変更
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.customWhite
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.standardAppearance = appearance
    }    
}

extension FriendListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellHeight = tableView.frame.size.height / NumericValues.friendListtableViewDivisior
        return cellHeight
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = friendListTableView.dequeueReusableCell(withIdentifier: FriendListTableViewCell.identifier, for: indexPath) as? FriendListTableViewCell else { return UITableViewCell() }
        let friendId = friends[indexPath.row].uid
        guard let friendsDetails = friendsDetails[friendId] else { return cell }
        configureCell(cell: cell, friendDetails: friendsDetails)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let friend = friends[indexPath.row]
        // フレンドとのメモがあればメモ詳細画面、なければメモ作成画面に遷移
        fetchMemoDetail(friendUid: friend.uid) { [weak self] result in
            guard let memoService = self?.memoService else { return }
            switch result {
            case .success(let memo):
                if let memo = memo {
                    self?.showMemoDetailVC(memo: memo)
                } else {
                    self?.showCreateMemoVC(friend: friend)
                }
            case .failure(let error):
                self?.showErrorAlert(error: error, memoService: memoService, managerType: .firestore)
            }
        }
        friendListTableView.deselectRow(at: indexPath, animated: true)
    }
}
