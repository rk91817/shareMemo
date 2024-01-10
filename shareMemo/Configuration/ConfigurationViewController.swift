import Foundation
import UIKit
import Nuke
import SafariServices

enum ConfigurationCell: Int, CaseIterable {
    case userNameCell
    case UIDCell
    case privacyPolicyCell
    case logoutCell
    case deleteAccountCell
}

final class ConfigurationViewController: UIViewController {
    @IBOutlet private weak var profileImageButton: UIButton!
    @IBOutlet private weak var configurationTableView: UITableView!
    var user: User?
    var memoService: MemoService?
    private var activityIndicator: UIActivityIndicatorView?
    private var overlayView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpButton()
        setUpTableView()
        makeProfileImageButtonRound()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getCurrentUser()
        setupMemoServiceErrorHandlers(memoService: memoService)
    }
    
    @objc private func tappedProfileImageButton() {
        showImagePickerController()
    }
    
    private func tappedPrivacyPolicyButton() {
        showSafariVC()
    }
    
    private func tappedLogoutButton() {
        logoutUser()
     }
    
    private func tappedDeleteUserButton() {
        showDeleteUserVC()
    }
    // 現在のユーザー情報を取得する処理
    private func getCurrentUser() {
        guard let currentUid = memoService?.currentUid else {
            memoService?.errorDidOccur?(AppError.userNotLogin, .none)
            return
        }
        memoService?.getUser(documentId: currentUid) { [weak self] result in
            switch result {
            case .success(let user):
                self?.user = user
                self?.configurationTableView.reloadData()
                self?.setUpProfileImage()
            case .failure: break
            }
        }
    }
    // プロフィール画像をstorageとfirestoreに保存する処理
    private func saveProfileImage(image: UIImage?) {
        showAOverlayIndicator()
        guard let image = image, let imageData = image.jpegData(compressionQuality: NumericValues.compressionQuality) else { return }
        
        memoService?.uploadImage(imageData: imageData) { [weak self] result in
            switch result {
            case .success(let urlString):
                guard let userId = self?.memoService?.currentUid else {
                    self?.memoService?.errorDidOccur?(AppError.userNotLogin, .none)
                    return
                }
                self?.memoService?.updateProfileImage(uid: userId, imageUrl: urlString) { [weak self] in
                    self?.hideOverlayIndicator()
                }
            case .failure: break
            }
        }
    }
    // ログアウト処理を呼び出す処理
    private func logoutUser() {
        memoService?.logout { [weak self] result in
            switch result {
            case .success:
                self?.showLoginVC()
            case .failure: break
            }
        }
    }
    // プライバシーポリシーのページに遷移する処理
    private func showSafariVC() {
        guard let privacyPolicyURL = URL(string: URLs.privacyPolicy) else { return }
        let safariVC = SFSafariViewController(url: privacyPolicyURL)
        present(safariVC, animated: true)
    }
    
    private func showDeleteUserVC() {
        let storyboard = UIStoryboard(name: StoryboardNames.deleteUser, bundle: nil)
        guard let deleteUserViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.deleteUserViewController) as? DeleteUserViewController else { return }
        deleteUserViewController.memoService = self.memoService
        navigationController?.pushViewController(deleteUserViewController, animated: true)
    }
    
    // ログアウト後にサインアップ画面に遷移する処理
    private func showLoginVC() {
        let storyboard = UIStoryboard(name: StoryboardNames.signUp, bundle: nil)
        guard let signUpViewController = storyboard.instantiateViewController(withIdentifier: VCIdentifiers.signUpViewController) as? SignUpViewController else { return }
        signUpViewController.memoService = self.memoService
        let nav = UINavigationController(rootViewController: signUpViewController)
        nav.modalPresentationStyle = .fullScreen
        self.present(nav, animated: true, completion: nil)
    }
    
    private func showImagePickerController() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        self.present(imagePickerController, animated: true, completion: nil)
    }
    // ロード中のオーバーレイとインジケーターを出す処理
    private func showAOverlayIndicator() {
        showOverlay()
        startActivityIndicator(in: self.view)
    }
    
    private func hideOverlayIndicator() {
        stopActivityIndicator()
            hideOverlay()
    }
    
    private func showOverlay() {
        guard let navView = self.navigationController?.view else { return }
        let overlay = UIView(frame: navView.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(NumericValues.MediumTransparency)
        overlay.isUserInteractionEnabled = true
        
        self.overlayView = overlay
        navView.addSubview(overlay)
    }
    
    private func hideOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
    
    private func startActivityIndicator(in view: UIView) {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.center = view.center
        indicator.startAnimating()
        self.activityIndicator = indicator
        view.addSubview(indicator)
    }
    
    private func stopActivityIndicator() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
    }
    // プロフィール画像ボタンを円形にする
    private func makeProfileImageButtonRound() {
        self.profileImageButton.layer.cornerRadius = self.profileImageButton.bounds.height / NumericValues.circleShapeDivisor
        self.profileImageButton.clipsToBounds = true
        self.profileImageButton.imageView?.contentMode = .scaleAspectFill
    }
    
    private func setUpButton() {
        profileImageButton.addTarget(self, action: #selector(tappedProfileImageButton), for: .touchUpInside )
    }
    
    private func setUpTableView() {
        configurationTableView.delegate = self
        configurationTableView.dataSource = self
        configurationTableView.register(ConfigurationTableViewCell.nib, forCellReuseIdentifier: ConfigurationTableViewCell.identifier)
    }
    
    private func setUpProfileImage() {
        // プロフィール画像がなければデフォルトの画像を設定
        guard let userImageURL = user?.profileImageUrl, let url = URL(string: userImageURL) else {
            self.profileImageButton.setImage(UIImage(named: ImageNames.defaultImage), for: .normal)
            return
        }
        guard let buttonImageView = profileImageButton.imageView else { return }
        startActivityIndicator(in: self.view)
        
        Nuke.loadImage(with: url, into: buttonImageView) { [weak self] result in
            switch result {
            case .success(let response):
                DispatchQueue.main.async {
                    self?.profileImageButton?.setImage(response.image, for: .normal)
                    self?.stopActivityIndicator()
                }
            case .failure: break
            }
        }
    }
}

extension ConfigurationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let editImage = info[.editedImage] as? UIImage {
            profileImageButton.setImage(editImage.withRenderingMode(.alwaysOriginal), for: .normal)
        } else if let originalImage = info[.originalImage] as? UIImage {
            profileImageButton.setImage(originalImage.withRenderingMode(.alwaysOriginal), for: .normal)
        }
        profileImageButton.imageView?.contentMode = .scaleAspectFill
        profileImageButton.contentHorizontalAlignment = .fill
        profileImageButton.contentVerticalAlignment = .fill
        profileImageButton.clipsToBounds = true
        saveProfileImage(image: profileImageButton.imageView?.image)
        self.dismiss(animated: true, completion: nil)
    }
}

extension ConfigurationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        ConfigurationCell.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = configurationTableView.dequeueReusableCell(withIdentifier: ConfigurationTableViewCell.identifier, for: indexPath) as? ConfigurationTableViewCell else { return UITableViewCell() }
        guard let uid = self.memoService?.currentUid else { return cell }
        let configurationCell = ConfigurationCell(rawValue: indexPath.row) // セルの列のEnum型ConfigurationCellを取得

        switch configurationCell {
        case .userNameCell: cell.configure(user: user, uid: uid, row: indexPath.row, celltype: .userNameCell)
        case .UIDCell: cell.configure(user: user, uid: uid, row: indexPath.row, celltype: .UIDCell)
        case .privacyPolicyCell:
            cell.configure(user: user, uid: uid, row: indexPath.row, celltype: .privacyPolicyCell)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        case .logoutCell:
            cell.configure(user: user, uid: uid, row: indexPath.row, celltype: .logoutCell)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        case .deleteAccountCell:
            cell.configure(user: user, uid: uid, row: indexPath.row, celltype: .deleteAccountCell)
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        case .none: break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellType = ConfigurationCell(rawValue: indexPath.row)
        switch cellType {
        case .userNameCell:
            break
        case .UIDCell:
            break
        case .privacyPolicyCell:
            showSafariVC()
        case .logoutCell:
            tappedLogoutButton()
        case .deleteAccountCell:
            tappedDeleteUserButton()
        case .none:
            break
        }
    }
    
     func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = tableView.backgroundColor
        return headerView
    }

     func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
         let headerHeight = NumericValues.tableViewHeaderHeight
         return headerHeight
    }
}
