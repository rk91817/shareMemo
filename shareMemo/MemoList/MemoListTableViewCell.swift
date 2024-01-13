import UIKit

final class MemoListTableViewCell: UITableViewCell {
    static let nib = UINib(nibName: String(describing: MemoListTableViewCell.self), bundle: nil)
    static let identifier = String(describing: MemoListTableViewCell.self)
    @IBOutlet private weak var memoNameLabel: UILabel!
    @IBOutlet private weak var lastUpdateTimeLabel: UILabel!
    @IBOutlet private weak var friendNameLabel: UILabel!
    override func prepareForReuse() {
        super.prepareForReuse()
        memoNameLabel.text = nil
        lastUpdateTimeLabel.text = nil
    }
    
    func defaultConfigure() {
        self.memoNameLabel.text = TextValues.fetching
        self.lastUpdateTimeLabel.text = TextValues.empty
        self.backgroundColor = UIColor.customWhite
    }
    
    func configure (name: String, time: Date) {
        self.memoNameLabel.text = name
        self.lastUpdateTimeLabel.text = dateFormatterForDateLabel(date: time)
        self.backgroundColor = UIColor.customWhite
    }
    
    private func dateFormatterForDateLabel(date: Date) -> String {
        let formatter = DateFormatter.shortDateFormatter
        return formatter.string(from: date)
    }
}
