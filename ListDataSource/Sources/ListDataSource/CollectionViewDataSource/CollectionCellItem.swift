//
//  CollectionCellItem.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import UIKit

public protocol ConfigurableCollectionCell {
    associatedtype DataType
    func configure(with item: DataType)
}


public protocol CollectionCellItem: Sendable {
    associatedtype T
    var cellIdentifier: String { get }
    var item: T { get }
    func configure(_ cell: UICollectionViewCell)
}

public extension CollectionCellItem {
    var itemType: T.Type { T.self }
}


public struct CollectionViewCellItem<T>: CollectionCellItem, @unchecked Sendable {
    public let item: T
    public let cellIdentifier: String
    private let configurator: @Sendable (UICollectionViewCell, T) -> Void

    public init(
        item: T,
        cellIdentifier: String,
        configure: @escaping @Sendable (UICollectionViewCell, T) -> Void
    ) {
        self.item = item
        self.cellIdentifier = cellIdentifier
        self.configurator = configure
    }

    public func configure(_ cell: UICollectionViewCell) {
        configurator(cell, item)
    }
}

public enum CollectionCellItemFactory {
    public static func make<Cell: UICollectionViewCell & ConfigurableCollectionCell, T>(
        cellType: Cell.Type,
        item: T,
        cellIdentifier: String = String(describing: Cell.self)
    ) -> any CollectionCellItem where Cell.DataType == T {
        CollectionViewCellItem(item: item, cellIdentifier: cellIdentifier) { cell, item in
            guard let typedCell = cell as? Cell else {
                assertionFailure("Expected cell of type \(Cell.self)")
                return
            }
            typedCell.configure(with: item)
        }
    }

    public static func make<T>(
        item: T,
        cellIdentifier: String,
        configure: @escaping @Sendable (UICollectionViewCell, T) -> Void
    ) -> any CollectionCellItem {
        CollectionViewCellItem(item: item, cellIdentifier: cellIdentifier, configure: configure)
    }
}
