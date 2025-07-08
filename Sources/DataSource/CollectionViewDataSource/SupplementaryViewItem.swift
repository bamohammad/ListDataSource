//
//  SupplementaryViewItem.swift
//  DataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import UIKit

public protocol ConfigurableSupplementaryView {
    associatedtype DataType
    func configure(with item: DataType)
}

public protocol SupplementaryViewItem: Sendable {
    associatedtype T
    var viewIdentifier: String { get }
    var item: T { get }
    var kind: String { get }
    func configure(_ view: UICollectionReusableView)
}

public struct DefaultSupplementaryViewItem<T>: SupplementaryViewItem, @unchecked Sendable {
    public let item: T
    public let viewIdentifier: String
    public let kind: String
    private let configurator: @Sendable (UICollectionReusableView, T) -> Void

    public init(
        item: T,
        viewIdentifier: String,
        kind: String,
        configure: @escaping @Sendable (UICollectionReusableView, T) -> Void
    ) {
        self.item = item
        self.viewIdentifier = viewIdentifier
        self.kind = kind
        self.configurator = configure
    }

    public func configure(_ view: UICollectionReusableView) {
        configurator(view, item)
    }
}

public enum SupplementaryViewFactory {
    public static func make<View: UICollectionReusableView & ConfigurableSupplementaryView, T>(
        viewType: View.Type,
        item: T,
        kind: String,
        viewIdentifier: String = String(describing: View.self)
    ) -> any SupplementaryViewItem where View.DataType == T {
        DefaultSupplementaryViewItem(item: item, viewIdentifier: viewIdentifier, kind: kind) { view, item in
            guard let typedView = view as? View else {
                assertionFailure("Expected view of type \(View.self)")
                return
            }
            typedView.configure(with: item)
        }
    }

    public static func make<T>(
        item: T,
        viewIdentifier: String,
        kind: String,
        configure: @escaping @Sendable (UICollectionReusableView, T) -> Void
    ) -> any SupplementaryViewItem {
        DefaultSupplementaryViewItem(item: item, viewIdentifier: viewIdentifier, kind: kind, configure: configure)
    }
}
