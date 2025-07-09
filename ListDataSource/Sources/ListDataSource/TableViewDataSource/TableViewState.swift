//
//  TableViewState.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

public enum TableViewState: Equatable, Sendable {
    case initial
    case loading(previousSections: [TableSection]? = nil)
    case loadingMore(currentSections: [TableSection], pagination: PaginationInfo?)
    case refreshing(currentSections: [TableSection])
    case loaded(sections: [TableSection], pagination: PaginationInfo?)
    case empty(config: EmptyStateConfiguration)
    case error(ViewError, previousSections: [TableSection]? = nil)
    case loadingMoreError(ViewError, currentSections: [TableSection], pagination: PaginationInfo?)

    public static func == (lhs: TableViewState, rhs: TableViewState) -> Bool {
        switch (lhs, rhs) {
        case (.initial, .initial):
            return true
        case let (.loading(lSections), .loading(rSections)):
            return lSections?.count == rSections?.count
        case let (.loadingMore(lSections, lPagination), .loadingMore(rSections, rPagination)):
            return lSections.count == rSections.count && lPagination == rPagination
        case let (.refreshing(lSections), .refreshing(rSections)):
            return lSections.count == rSections.count
        case let (.loaded(lSections, lPagination), .loaded(rSections, rPagination)):
            return lSections.count == rSections.count && lPagination == rPagination
        case let (.empty(lConfig), .empty(rConfig)):
            return lConfig == rConfig
        case let (.error(lError, lSections), .error(rError, rSections)):
            return lError == rError && lSections?.count == rSections?.count
        case let (.loadingMoreError(lError, lSections, lPagination), .loadingMoreError(rError, rSections, rPagination)):
            return lError == rError && lSections.count == rSections.count && lPagination == rPagination
        default:
            return false
        }
    }

    public var sections: [TableSection] {
        switch self {
        case let .loaded(sections, _):
            return sections
        case let .loadingMore(sections, _),
             let .refreshing(sections),
             let .loadingMoreError(_, sections, _):
            return sections
        case let .loading(previousSections),
             let .error(_, previousSections):
            return previousSections ?? []
        default:
            return []
        }
    }

    public var loadingState: LoadingState {
        switch self {
        case .loading:
            return .loading
        case let .loadingMore(_, pagination):
            return .loadingMore(page: pagination?.currentPage ?? 1)
        case .refreshing:
            return .refreshing
        default:
            return .none
        }
    }

    public var pagination: PaginationInfo? {
        switch self {
        case let .loaded(_, pagination),
             let .loadingMore(_, pagination),
             let .loadingMoreError(_, _, pagination):
            return pagination
        default:
            return nil
        }
    }

    public var error: ViewError? {
        switch self {
        case let .error(error, _),
             let .loadingMoreError(error, _, _):
            return error
        default:
            return nil
        }
    }
}
