import UIKit
import Nuke

final class FriendListTableViewCell: UITableViewCell {
    static let nib = UINib(nibName: String(describing: FriendListTableViewCell.self), bundle: nil)
    static let identifier = String(describing: FriendListTableViewCell.self)

    @IBOutlet private weak var friendImageView: UIImageView!
    @IBOutlet private weak var friendNameLabel: UILabel!
    private var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .medium)
    var imageTappedClosure: (() -> Void)?//　プロフィール画像をタップされたときに呼ばれるクロージャ

    
    override func layoutSubviews() {
        super.layoutSubviews()
        setImageView()
        setupTapGesture()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        friendImageView.image = nil
        friendNameLabel.text = nil
    }
    
    // friendImageViewをカプセル化するためのメソッド
    func currentImage() -> UIImage? {
        return friendImageView.image
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        friendImageView.isUserInteractionEnabled = true
        friendImageView.addGestureRecognizer(tapGesture)
    }

    @objc func imageTapped() {
        imageTappedClosure?()
    }
    
    // 画像を円形にする処理
    private func setImageView() {
        friendImageView.layer.cornerRadius = friendImageView.frame.size.width / NumericValues.circleShapeDivisor
        friendImageView.layer.masksToBounds = true
    }
    
    private func showActivityIndicator(in view: UIView) {
        view.addSubview(activityIndicator)
        activityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        activityIndicator.startAnimating()
    }

    private func hideActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.removeFromSuperview()
    }
    
    func configure (name: String, profileImageUrl: String) {
        self.friendNameLabel.text = name
        showActivityIndicator(in: friendImageView)
        if let url = URL(string: profileImageUrl), let imageView = self.friendImageView {
            Nuke.loadImage(with: url, into: imageView) { [weak self] _ in
                self?.hideActivityIndicator()
            }
        } else {
            hideActivityIndicator()
            friendImageView.image = UIImage(named: ImageNames.noImage)
        }
    }
}
