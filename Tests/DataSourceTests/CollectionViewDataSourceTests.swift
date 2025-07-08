//
//  CollectionViewDataSourceTests.swift
//  DataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//

import Combine
@testable import DataSource
import XCTest

@MainActor
final class CollectionViewDataSourceTests: XCTestCase {
    private struct DummyItem: Equatable, Sendable {
        let value: Int
    }

    private final class DummyCell: UICollectionViewCell, @preconcurrency ConfigurableCollectionCell {
        typealias DataType = DummyItem
        private(set) var configuredItem: DummyItem?
        func configure(with item: DummyItem) {
            configuredItem = item
            backgroundColor = .systemBlue
        }
    }

    private func makeSections(count: Int = 3, items: Int = 5) -> [CollectionSection] {
        (0 ..< count).map { sectionIndex in
            let cellItems: [any CollectionCellItem] = (0 ..< items).map { itemIndex in
                CollectionCellItemFactory.make(cellType: DummyCell.self,
                                               item: DummyItem(value: sectionIndex * 10 + itemIndex))
            }
            return DefaultCollectionSection(items: cellItems)
        }
    }

    func testInitialState_isInitial() {
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Initial state published")
        var receivedStates = [CollectionViewState]()
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
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
        let sections = makeSections(count: 2, items: 4)
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

    func testCollectionViewDataSource_numbersMatchState() {
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.register(DummyCell.self, forCellWithReuseIdentifier: String(describing: DummyCell.self))
        dataSource.attach(to: collectionView)

        let sections = makeSections(count: 2, items: 3)
        dataSource.update(sections: sections)

        XCTAssertEqual(dataSource.numberOfSections(in: collectionView), 2)
        XCTAssertEqual(dataSource.collectionView(collectionView, numberOfItemsInSection: 0), 3)
    }

    func testSelectionHandler_invokedWithCorrectItem() {
        let expectation = expectation(description: "SelectionHandler called")
        let handler = CollectionSelectionHandler()
        handler.addHandler(for: DummyItem.self) { item in
            XCTAssertEqual(item, DummyItem(value: 0))
            expectation.fulfill()
        }
        let dataSource = CollectionViewDataSourceFactory.makeDataSource(selectionHandler: handler)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.register(DummyCell.self, forCellWithReuseIdentifier: String(describing: DummyCell.self))
        dataSource.attach(to: collectionView)

        let sections = makeSections(count: 1, items: 1)
        dataSource.update(sections: sections)

        let indexPath = IndexPath(item: 0, section: 0)
        _ = dataSource.collectionView(collectionView, cellForItemAt: indexPath)
        dataSource.collectionView(collectionView, didSelectItemAt: indexPath)

        wait(for: [expectation], timeout: 1)
    }

    func testLoadMoreHandler_calledWhenAppropriate() {
        let loadMoreExpectation = expectation(description: "Load more triggered")
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.register(DummyCell.self, forCellWithReuseIdentifier: String(describing: DummyCell.self))

        dataSource.attach(to: collectionView, loadMore: { _ in
            loadMoreExpectation.fulfill()
        })

        let pagination = PaginationInfo(currentPage: 1,
                                        totalItems: 100,
                                        hasMorePages: true,
                                        itemsPerPage: 25)
        let sections = makeSections(count: 1, items: 25)
        dataSource.send(.loaded(sections: sections, pagination: pagination))

        let indexPath = IndexPath(item: 24, section: 0)
        _ = dataSource.collectionView(collectionView, cellForItemAt: indexPath)

        wait(for: [loadMoreExpectation], timeout: 1)
    }

    func testRefreshControl_invokesHandler() {
        let refreshExpectation = expectation(description: "Refresh handler called")
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()

        dataSource.attach(to: collectionView, refresh: {
            refreshExpectation.fulfill()
        })

        // Trigger refresh via internal selector
        dataSource.perform(Selector(("handleRefresh")))

        wait(for: [refreshExpectation], timeout: 1)
    }

    func testEmptyState_showsEmptyView() {
        let emptyViewExpectation = expectation(description: "Empty view provider called")

        var config = CollectionViewDataSource.Configuration()
        config.emptyStateViewProvider = { @Sendable config in
            XCTAssertEqual(config.title, "No Items")
            XCTAssertEqual(config.subtitle, "Pull to refresh")
            emptyViewExpectation.fulfill()
            return MainActor.assumeIsolated {
                return UIView()
            }
        }

        let dataSource = CollectionViewDataSource(configuration: config)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        dataSource.attach(to: collectionView)

        let emptyConfig = EmptyStateConfiguration(title: "No Items",
                                                  subtitle: "Pull to refresh",
                                                  image: UIImage(systemName: "square.and.pencil.circle.fill"),
                                                  backgroundColor: .white)

        dataSource.send(.empty(config: emptyConfig))

        wait(for: [emptyViewExpectation], timeout: 1)
        XCTAssertNotNil(collectionView.backgroundView)
    }

    func testEmptyState_publishesCorrectState() {
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
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
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
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
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Error state with previous sections")

        let previousSections = makeSections(count: 1, items: 2)
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
        let dataSource = CollectionViewDataSourceFactory.makeDataSource()
        let expectation = expectation(description: "Loading more error state")

        let currentSections = makeSections(count: 2, items: 3)
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
