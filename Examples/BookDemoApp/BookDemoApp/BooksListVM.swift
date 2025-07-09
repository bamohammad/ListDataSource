//
//  BooksListVM.swift
//  BookDemoApp
//
//  Created by Ali Bamohammad on 09/07/2025.
//

import Combine
import ListDataSource
import Foundation

@MainActor
final class BooksListVM {
    // MARK: - Constants

    private let itemsPerPage = 30
    private let totalPages = 3
    private var currentPage = 1

    // MARK: - Streams

    private let stateSubject = PassthroughSubject<TableViewState, Never>()
    var dataSourceStream: AnyPublisher<TableViewState, Never> { stateSubject.eraseToAnyPublisher() }

    /// Storage
    private var books: [Book] = []

    // MARK: - Public API

    func loadData() async {
        await setState(.loading())
        await loadPage(1)
    }

    func refresh() async {
        await setState(.refreshing(currentSections: currentSections))
        currentPage = 1
        books.removeAll()
        await loadPage(1)
    }

    func loadMoreIfNeeded(currentIndex index: Int) async {
        guard index >= books.count - 3,
              currentPage < totalPages else {
            return
        }

        let pagination = PaginationInfo(currentPage: currentPage,
                                        totalItems: itemsPerPage * totalPages,
                                        hasMorePages: true,
                                        itemsPerPage: itemsPerPage)
        await setState(.loadingMore(currentSections: currentSections, pagination: pagination))
        await loadPage(currentPage + 1)
    }

    // MARK: - Internal helpers

    private var currentSections: [TableSection] {
        let items = books
            .map {
                CellItemFactory.make(cellType: BookCell.self, item: $0, cellIdentifier: "BookCell")
            }
        return [DefaultSection(items: items)]
    }

    private func loadPage(_ page: Int) async {
        do {
            try await Task.sleep(nanoseconds: 700_000_000)
            // Simulate error on page 3
            if page == 3 {
                throw URLError(.badServerResponse)
            }

            let newBooks = (0 ..< itemsPerPage).map {
                Book(id: UUID(), title: "Book \($0 + (page - 1) * itemsPerPage)")
            }

            if page == 1 {
                books = newBooks
            } else {
                books += newBooks
            }
            currentPage = page

            let pagination = PaginationInfo(currentPage: currentPage,
                                            totalItems: itemsPerPage * totalPages,
                                            hasMorePages: currentPage < totalPages,
                                            itemsPerPage: itemsPerPage)

            await setState(.loaded(sections: currentSections, pagination: pagination))

        } catch {
            let viewError = ViewError(message: "Failed to load books", underlyingError: error)
            if page == 1 {
                await setState(.error(viewError, previousSections: []))
            } else {
                let pagination = PaginationInfo(currentPage: currentPage,
                                                totalItems: itemsPerPage * totalPages,
                                                hasMorePages: true,
                                                itemsPerPage: itemsPerPage)
                await setState(.loadingMoreError(viewError, currentSections: currentSections, pagination: pagination))
            }
        }
    }

    private func setState(_ state: TableViewState) async {
        stateSubject.send(state)
    }
}
