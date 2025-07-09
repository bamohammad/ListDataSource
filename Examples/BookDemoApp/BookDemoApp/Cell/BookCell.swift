
import UIKit
import ListDataSource

final class BookCell: UITableViewCell, ConfigurableTableCell {
    @IBOutlet weak var titleLabel: UILabel!

    func configure(with item: Book) {
        titleLabel.text = item.title
    }
}
