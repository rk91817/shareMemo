import UIKit

final class ConfigurationTableViewCell: UITableViewCell {
    static let nib = UINib(nibName: String(describing: ConfigurationTableViewCell.self), bundle: nil)
    static let identifier = String(describing: ConfigurationTableViewCell.self)
    private let cellNameArray = ["ユーザーネーム", "ユーザーID", "プライバシーポリシー", "ログアウト", "退会する"]
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var detailLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        detailLabel.text = nil
        accessoryType = .none
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setGestureRecognizer()
    }
    // detailLabelにジェスチャを追加する処理
    private func setGestureRecognizer() {
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longTapCopyEvent))
        gestureRecognizer.minimumPressDuration = NumericValues.minimumPressDuration// 長押しをどれくらいの時間行う必要があるか
        gestureRecognizer.allowableMovement = NumericValues.allowableMovement// ジェスチャー中に指が動ける最大の距離
        detailLabel.addGestureRecognizer(gestureRecognizer)
    }
    
    // detailLabelに長押しでコピー可能にする処理
    @objc private func longTapCopyEvent(sender: UILongPressGestureRecognizer) {
        // 長押し判定時のみ処理する
        guard sender.state == .began else { return }
        UIPasteboard.general.string = detailLabel.text
    }
    
    func configure(user: User?, uid: String, row: Int, celltype: ConfigurationCell) {
        titleLabel.text = cellNameArray[row]
        switch celltype {
        case .userNameCell:
            detailLabel.text = user?.username ?? TextValues.fetching
        case .UIDCell:
            detailLabel.text = uid
        case .privacyPolicyCell, .logoutCell, .deleteAccountCell:
            break
        }
    }
}
