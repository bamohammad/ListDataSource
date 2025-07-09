//
//  PaginationInfo.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

public struct PaginationInfo: Equatable, Sendable {
    public let currentPage: Int
    public let totalItems: Int
    public let hasMorePages: Bool
    public let itemsPerPage: Int

    public init(currentPage: Int, totalItems: Int, hasMorePages: Bool, itemsPerPage: Int) {
        self.currentPage = currentPage
        self.totalItems = totalItems
        self.hasMorePages = hasMorePages
        self.itemsPerPage = itemsPerPage
    }

    public static var initial: PaginationInfo {
        PaginationInfo(currentPage: 1, totalItems: Int.max, hasMorePages: false, itemsPerPage: 20)
    }
}
