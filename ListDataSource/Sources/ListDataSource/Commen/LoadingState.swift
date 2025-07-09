//
//  LoadingState.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

public enum LoadingState: Equatable, Sendable {
    case none
    case loading
    case loadingMore(page: Int)
    case refreshing

    public var isLoading: Bool {
        switch self {
        case .loading, .loadingMore, .refreshing: return true
        case .none: return false
        }
    }
}
