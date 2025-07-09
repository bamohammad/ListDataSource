//
//  TableCellItem.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import UIKit

public protocol ConfigurableTableCell {
    associatedtype DataType
    func configure(with item: DataType)
}

public protocol TableCellItem: Sendable {
    associatedtype T
    var cellIdentifier: String { get }
    var item: T { get }
    func configure(_ cell: UITableViewCell)
}

public extension TableCellItem {
    var itemType: T.Type { T.self }
}

public struct TableViewCellItem<T>: TableCellItem, @unchecked Sendable {
    public let item: T
    public let cellIdentifier: String
    private let configurator: @Sendable (UITableViewCell, T) -> Void

    public init(item: T,
                cellIdentifier: String,
                configure: @escaping @Sendable (UITableViewCell, T) -> Void) {
        self.item = item
        self.cellIdentifier = cellIdentifier
        configurator = configure
    }

    public func configure(_ cell: UITableViewCell) {
        configurator(cell, item)
    }
}

// MARK: - Cell Item Factory

public enum CellItemFactory {
    public static func make<Cell: UITableViewCell & ConfigurableTableCell, T>(cellType: Cell.Type,
                                                                         item: T,
                                                                         cellIdentifier: String = String(describing: Cell.self)) -> any TableCellItem where Cell.DataType == T {
        TableViewCellItem(item: item, cellIdentifier: cellIdentifier) { cell, item in
            guard let typedCell = cell as? Cell else {
                assertionFailure("Expected cell of type \(Cell.self)")
                return
            }
            typedCell.configure(with: item)
        }
    }

    public static func make<T>(item: T,
                               cellIdentifier: String,
                               configure: @escaping @Sendable (UITableViewCell, T) -> Void) -> any TableCellItem {
        TableViewCellItem(item: item, cellIdentifier: cellIdentifier, configure: configure)
    }
}
