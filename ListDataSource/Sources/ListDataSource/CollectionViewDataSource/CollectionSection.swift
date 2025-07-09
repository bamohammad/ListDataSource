//
//  CollectionSection.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//

import UIKit


public protocol CollectionSection: Sendable {
    var items: [any CollectionCellItem] { get }
    var headerItem: (any SupplementaryViewItem)? { get }
    var footerItem: (any SupplementaryViewItem)? { get }
    var sectionInsets: UIEdgeInsets { get }
    var minimumLineSpacing: CGFloat { get }
    var minimumInteritemSpacing: CGFloat { get }
}


// MARK: - Default Section Implementation

public extension CollectionSection {
    var headerItem: (any SupplementaryViewItem)? { nil }
    var footerItem: (any SupplementaryViewItem)? { nil }
    var sectionInsets: UIEdgeInsets { .zero }
    var minimumLineSpacing: CGFloat { 0 }
    var minimumInteritemSpacing: CGFloat { 0 }
}

public struct DefaultCollectionSection: CollectionSection, @unchecked Sendable {
    public let items: [any CollectionCellItem]
    public var sectionInsets: UIEdgeInsets = .zero
    public var minimumLineSpacing: CGFloat = 0
    public var minimumInteritemSpacing: CGFloat = 0
    
    public init(items: [any CollectionCellItem]) {
        self.items = items
    }
    
    public init(
        items: [any CollectionCellItem],
        sectionInsets: UIEdgeInsets = .zero,
        minimumLineSpacing: CGFloat = 0,
        minimumInteritemSpacing: CGFloat = 0
    ) {
        self.items = items
        self.sectionInsets = sectionInsets
        self.minimumLineSpacing = minimumLineSpacing
        self.minimumInteritemSpacing = minimumInteritemSpacing
    }
}

public struct HeaderFooterCollectionSection: CollectionSection, @unchecked Sendable {
    public let items: [any CollectionCellItem]
    public let headerItem: (any SupplementaryViewItem)?
    public let footerItem: (any SupplementaryViewItem)?
    public var sectionInsets: UIEdgeInsets = .zero
    public var minimumLineSpacing: CGFloat = 0
    public var minimumInteritemSpacing: CGFloat = 0
    
    public init(
        items: [any CollectionCellItem],
        headerItem: (any SupplementaryViewItem)? = nil,
        footerItem: (any SupplementaryViewItem)? = nil,
        sectionInsets: UIEdgeInsets = .zero,
        minimumLineSpacing: CGFloat = 0,
        minimumInteritemSpacing: CGFloat = 0
    ) {
        self.items = items
        self.headerItem = headerItem
        self.footerItem = footerItem
        self.sectionInsets = sectionInsets
        self.minimumLineSpacing = minimumLineSpacing
        self.minimumInteritemSpacing = minimumInteritemSpacing
    }
}
