//
//  TableSection.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import UIKit

public protocol TableSection: Sendable {
    var items: [any TableCellItem] { get }
    var headerTitle: String? { get }
    var footerTitle: String? { get }
    var headerHeight: CGFloat { get }
    var footerHeight: CGFloat { get }
    func headerView(for tableView: UITableView, at section: Int) -> UIView?
    func footerView(for tableView: UITableView, at section: Int) -> UIView?
}

// MARK: - Default Section Implementation

public extension TableSection {
    var headerHeight: CGFloat { 0 } // 0 means use automatic sizing (converted to 44.0 in delegate)
    var footerHeight: CGFloat { 0 } // 0 means use automatic sizing (converted to 44.0 in delegate)
    var headerTitle: String? { nil }
    var footerTitle: String? { nil }
    func headerView(for tableView: UITableView, at section: Int) -> UIView? { nil }
    func footerView(for tableView: UITableView, at section: Int) -> UIView? { nil }
}

// MARK: - Concrete Section Types

public struct DefaultSection: TableSection, @unchecked Sendable {
    public let items: [any TableCellItem]
    public var headerHeight: CGFloat = CGFloat.leastNonzeroMagnitude
    public var footerHeight: CGFloat = CGFloat.leastNonzeroMagnitude
    
    public init(items: [any TableCellItem]) {
        self.items = items
    }
}

public struct TitledSection: TableSection, @unchecked Sendable {
    public let headerTitle: String?
    public let footerTitle: String?
    public let items: [any TableCellItem]

    public init(headerTitle: String? = nil, footerTitle: String? = nil, items: [any TableCellItem]) {
        self.headerTitle = headerTitle
        self.footerTitle = footerTitle
        self.items = items
    }
}
