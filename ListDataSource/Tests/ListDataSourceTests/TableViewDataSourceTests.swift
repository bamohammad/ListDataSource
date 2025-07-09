//
//  TableViewDataSourceTests.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//

import Combine
@testable import ListDataSource
import XCTest

@MainActor
final class TableViewDataSourceTests: XCTestCase {
    private struct DummyItem: Equatable, Sendable {
        let value: Int
    }

    private final class DummyCell: UITableViewCell, @preconcurrency ConfigurableTableCell {
        typealias DataType = DummyItem
        private(set) var configuredItem: DummyItem?
        func configure(with item: DummyItem) {
            configuredItem = item
            textLabel?.text = "\(item.value)"
        }
    }

    private func makeSections(count: Int = 3, rows: Int = 5) -> [TableSection] {
        (0 ..< count).map { sectionIndex in
            let items: [any TableCellItem] = (0 ..< rows).map { rowIndex in
                CellItemFactory.make(cellType: DummyCell.self,
                                     item: DummyItem(value: sectionIndex * 10 + rowIndex))
            }
            return DefaultSection(items: items)
        }
    }

    func testInitialState_isInitial() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Initial state published")
        var receivedStates = [TableViewState]()
        let cancellable = dataSource.statePublisher
            .sink { state in
                receivedStates.append(state)
                if receivedStates.count == 1 {
                    expectation.fulfill()
                }
            }
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedStates.first, .initial)
        cancellable.cancel()
    }

    func testSendLoaded_updatesSectionsAndPublishers() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let sections = makeSections(count: 2, rows: 4)
        let expectation = expectation(description: "Loaded state published")
        let cancellable = dataSource.sectionsPublisher
            .dropFirst()
            .sink { publishedSections in
                XCTAssertEqual(publishedSections.count, sections.count)
                expectation.fulfill()
            }

        dataSource.send(.loaded(sections: sections, pagination: nil))
        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testTableViewDataSource_numbersMatchState() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let tableView = UITableView()
        tableView.register(DummyCell.self, forCellReuseIdentifier: String(describing: DummyCell.self))
        dataSource.attach(to: tableView)

        let sections = makeSections(count: 2, rows: 3)
        dataSource.update(sections: sections)

        XCTAssertEqual(dataSource.numberOfSections(in: tableView), 2)
        XCTAssertEqual(dataSource.tableView(tableView, numberOfRowsInSection: 0), 3)
    }

    func testSelectionHandler_invokedWithCorrectItem() {
        let expectation = expectation(description: "SelectionHandler called")
        let handler = TableSelectionHandler()
        handler.addHandler(for: DummyItem.self) { item in
            XCTAssertEqual(item, DummyItem(value: 0))
            expectation.fulfill()
        }
        let dataSource = TableViewDataSourceFactory.makeDataSource(selectionHandler: handler)

        let tableView = UITableView()
        tableView.register(DummyCell.self, forCellReuseIdentifier: String(describing: DummyCell.self))
        dataSource.attach(to: tableView)

        let sections = makeSections(count: 1, rows: 1)
        dataSource.update(sections: sections)

        let indexPath = IndexPath(row: 0, section: 0)
        _ = dataSource.tableView(tableView, cellForRowAt: indexPath)
        dataSource.tableView(tableView, didSelectRowAt: indexPath)

        wait(for: [expectation], timeout: 1)
    }

    func testLoadMoreHandler_calledWhenAppropriate() {
        let loadMoreExpectation = expectation(description: "Load more triggered")
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let tableView = UITableView()
        tableView.register(DummyCell.self, forCellReuseIdentifier: String(describing: DummyCell.self))

        dataSource.attach(to: tableView, loadMore: { _ in
            loadMoreExpectation.fulfill()
        })

        let pagination = PaginationInfo(currentPage: 1,
                                        totalItems: 100,
                                        hasMorePages: true,
                                        itemsPerPage: 25)
        let sections = makeSections(count: 1, rows: 25)
        dataSource.send(.loaded(sections: sections, pagination: pagination))

        let indexPath = IndexPath(row: 24, section: 0)
        _ = dataSource.tableView(tableView, cellForRowAt: indexPath)

        wait(for: [loadMoreExpectation], timeout: 1)
    }

    func testRefreshControl_invokesHandler() {
        let refreshExpectation = expectation(description: "Refresh handler called")
        let tableView = UITableView()
        let dataSource = TableViewDataSourceFactory.makeDataSource()

        dataSource.attach(to: tableView, refresh: {
            refreshExpectation.fulfill()
        })

        // Trigger refresh via internal selector
        dataSource.perform(Selector(("handleRefresh")))

        wait(for: [refreshExpectation], timeout: 1)
    }

    func testEmptyState_showsEmptyView() {
        let emptyViewExpectation = expectation(description: "Empty view provider called")

        var config = TableViewDataSource.Configuration()
        config.emptyStateViewProvider = { @Sendable config in
            XCTAssertEqual(config.title, "No Items")
            XCTAssertEqual(config.subtitle, "Pull to refresh")
            emptyViewExpectation.fulfill()
            return MainActor.assumeIsolated {
                return UIView()
            }
        }

        let dataSource = TableViewDataSource(configuration: config)
        let tableView = UITableView()
        dataSource.attach(to: tableView)

        let emptyConfig = EmptyStateConfiguration(title: "No Items",
                                                  subtitle: "Pull to refresh",
                                                  image: UIImage(systemName: "square.and.pencil.circle.fill"),
                                                  backgroundColor: .white)

        dataSource.send(.empty(config: emptyConfig))

        wait(for: [emptyViewExpectation], timeout: 1)
        XCTAssertNotNil(tableView.backgroundView)
    }

    func testEmptyState_publishesCorrectState() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Empty state published")

        let cancellable = dataSource.statePublisher
            .dropFirst()
            .sink { state in
                if case let .empty(config) = state {
                    XCTAssertEqual(config.title, "Test Empty")
                    expectation.fulfill()
                }
            }

        let emptyConfig = EmptyStateConfiguration(title: "Test Empty")
        dataSource.send(.empty(config: emptyConfig))

        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testErrorState_publishesError() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Error state published")

        let cancellable = dataSource.errorPublisher
            .compactMap { $0 }
            .sink { error in
                XCTAssertEqual(error.message, "Test error")
                expectation.fulfill()
            }

        let testError = ViewError(message: "Test error")
        dataSource.send(.error(testError, previousSections: []))

        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testErrorState_maintainsPreviousSections() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Error state with previous sections")

        let previousSections = makeSections(count: 1, rows: 2)
        let cancellable = dataSource.statePublisher
            .dropFirst()
            .sink { state in
                if case let .error(error, sections) = state {
                    XCTAssertEqual(error.message, "Network error")
                    XCTAssertEqual(sections?.count, 1)
                    expectation.fulfill()
                }
            }

        let testError = ViewError(message: "Network error")
        dataSource.send(.error(testError, previousSections: previousSections))

        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }

    func testLoadingMoreError_preservesCurrentSections() {
        let dataSource = TableViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Loading more error state")

        let currentSections = makeSections(count: 2, rows: 3)
        let pagination = PaginationInfo(currentPage: 2, totalItems: 50, hasMorePages: true, itemsPerPage: 10)

        let cancellable = dataSource.statePublisher
            .dropFirst()
            .sink { state in
                if case let .loadingMoreError(error, sections, paginationInfo) = state {
                    XCTAssertEqual(error.message, "Load more failed")
                    XCTAssertEqual(sections.count, 2)
                    XCTAssertEqual(paginationInfo?.currentPage, 2)
                    expectation.fulfill()
                }
            }

        let testError = ViewError(message: "Load more failed")
        dataSource.send(.loadingMoreError(testError, currentSections: currentSections, pagination: pagination))

        wait(for: [expectation], timeout: 1)
        cancellable.cancel()
    }
}
