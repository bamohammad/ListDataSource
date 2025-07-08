//
//  CollectionViewDataSource.swift
//  DataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//

import Combine
import UIKit

public extension CollectionViewDataSource {
    struct Configuration: Sendable {
        public var showLoadingIndicator: Bool = true
        public var loadingIndicatorSize: CGSize = .init(width: 50,
                                                        height: 50)
        public var emptyStateViewProvider: (@Sendable (EmptyStateConfiguration) -> UIView)?

        public init() {}

        public static var `default`: Configuration {
            Configuration()
        }
    }
}

// MARK: - Collection View Data Source

@MainActor
public final class CollectionViewDataSource: NSObject {
    // MARK: - Types

    public typealias LoadMoreHandler = @Sendable (Int) -> Void
    public typealias RefreshHandler = @Sendable () -> Void

    // MARK: - Properties

    private var state: CollectionViewState
    private let selectionHandler: CollectionSelectionHandler?
    private weak var collectionView: UICollectionView?
    private let configuration: Configuration

    private var loadMoreHandler: LoadMoreHandler?
    private var refreshHandler: RefreshHandler?

    // MARK: - AsyncStream Support

    private var asyncContinuation: AsyncStream<CollectionViewState>.Continuation?
    private lazy var asyncUpdates: AsyncStream<CollectionViewState> = AsyncStream { self.asyncContinuation = $0 }

    public var stateStream: AsyncStream<CollectionViewState> {
        asyncUpdates
    }

    // MARK: - Combine Support

    private let stateSubject = CurrentValueSubject<CollectionViewState, Never>(.initial)
    private var cancellables = Set<AnyCancellable>()

    public var statePublisher: AnyPublisher<CollectionViewState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var sectionsPublisher: AnyPublisher<[CollectionSection], Never> {
        stateSubject
            .map(\.sections)
            .removeDuplicates { $0.count == $1.count }
            .eraseToAnyPublisher()
    }

    public var loadingStatePublisher: AnyPublisher<LoadingState, Never> {
        stateSubject
            .map(\.loadingState)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var errorPublisher: AnyPublisher<ViewError?, Never> {
        stateSubject
            .map(\.error)
            .removeDuplicates { lhs, rhs in
                switch (lhs, rhs) {
                case (.none, .none): return true
                case let (.some(l), .some(r)): return l == r
                default: return false
                }
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Loading View

    private lazy var loadingView: UIView? = {
        guard configuration.showLoadingIndicator else {
            return nil
        }

        let view = UIView(frame: CGRect(origin: .zero, size: configuration.loadingIndicatorSize))
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        return view
    }()

    // MARK: - Initialization

    public init(initialState: CollectionViewState = .initial,
                selectionHandler: CollectionSelectionHandler? = nil,
                configuration: Configuration = .default) {
        state = initialState
        self.selectionHandler = selectionHandler
        self.configuration = configuration
        super.init()

        stateSubject.send(initialState)
        setupUpdateHandling()
    }

    deinit {
        asyncContinuation?.finish()
    }
}

// MARK: - Public Interface

public extension CollectionViewDataSource {
    func attach(to collectionView: UICollectionView,
                loadMore: LoadMoreHandler? = nil,
                refresh: RefreshHandler? = nil) {
        self.collectionView = collectionView
        loadMoreHandler = loadMore
        refreshHandler = refresh

        collectionView.dataSource = self
        collectionView.delegate = self

        setupRefreshControl(for: collectionView)
    }

    func send(_ newState: CollectionViewState) {
        state = newState

        // Send to both AsyncStream and Combine
        asyncContinuation?.yield(newState)
        stateSubject.send(newState)
    }

    func update(sections: [CollectionSection], pagination: PaginationInfo? = nil) {
        let newState: CollectionViewState = sections.isEmpty
            ? .empty(config: .init())
            : .loaded(sections: sections, pagination: pagination)
        send(newState)
    }
}

// MARK: - AsyncStream Convenience Methods

public extension CollectionViewDataSource {
    func observeState() -> AsyncStream<CollectionViewState> {
        stateStream
    }

    func observeSections() -> AsyncStream<[CollectionSection]> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    return
                }
                for await state in self.stateStream {
                    continuation.yield(state.sections)
                }
            }
        }
    }

    func observeLoadingState() -> AsyncStream<LoadingState> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    return
                }
                for await state in self.stateStream {
                    continuation.yield(state.loadingState)
                }
            }
        }
    }

    func observeErrors() -> AsyncStream<ViewError?> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    return
                }
                for await state in self.stateStream {
                    continuation.yield(state.error)
                }
            }
        }
    }
}

// MARK: - Combine Convenience Methods

public extension CollectionViewDataSource {
    func bindToViewModel<VM: ObservableObject>(_ viewModel: VM,
                                               stateKeyPath: ReferenceWritableKeyPath<VM, CollectionViewState>) -> AnyCancellable {
        statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: stateKeyPath, on: viewModel)
    }

    func bindSections<VM: ObservableObject>(to viewModel: VM,
                                            keyPath: ReferenceWritableKeyPath<VM, [CollectionSection]>) -> AnyCancellable {
        sectionsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: viewModel)
    }
}

// MARK: - Private Methods

private extension CollectionViewDataSource {
    func setupUpdateHandling() {
        statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleUpdate(newState)
            }
            .store(in: &cancellables)
    }

    func setupRefreshControl(for collectionView: UICollectionView) {
        guard refreshHandler != nil else {
            return
        }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    func handleUpdate(_ newState: CollectionViewState) {
        let oldState = state
        state = newState

        updateLoadingViews()
        updateEmptyState()
        updateRefreshControl(from: oldState)
        reloadCollectionView()
    }

    func updateLoadingViews() {
        switch state.loadingState {
        case .loading:
            // Use backgroundView for main loading (like empty state)
            if let loadingView = loadingView {
                collectionView?.backgroundView = loadingView
            }
        case .loadingMore:
            // Collection views handle "load more" differently
            // Could use supplementary views or custom approach
            break
        default:
            // Clear loading view only if it's there
            if collectionView?.backgroundView === loadingView {
                collectionView?.backgroundView = nil
            }
        }
    }

    func updateEmptyState() {
        if case let .empty(config) = state,
           let provider = configuration.emptyStateViewProvider {
            collectionView?.backgroundView = provider(config)
        } else {
            collectionView?.backgroundView = nil
        }
    }

    func updateRefreshControl(from oldState: CollectionViewState) {
        if case .refreshing = oldState {
            collectionView?.refreshControl?.endRefreshing()
        }
    }

    func reloadCollectionView() {
        collectionView?.reloadData()
    }

    func shouldLoadMore(at indexPath: IndexPath) -> Bool {
        guard let pagination = state.pagination,
              pagination.hasMorePages,
              !state.loadingState.isLoading else {
            return false
        }

        // Check if we're near the end (last 5 items)
        let totalItems = state.sections.reduce(0) { $0 + $1.items.count }
        let currentItem = state.sections.prefix(indexPath.section).reduce(0) { $0 + $1.items.count } + indexPath.item

        return currentItem >= totalItems - 5
    }

    func itemAt(_ indexPath: IndexPath) -> (any CollectionCellItem)? {
        guard indexPath.section < state.sections.count,
              indexPath.item < state.sections[indexPath.section].items.count else {
            return nil
        }
        return state.sections[indexPath.section].items[indexPath.item]
    }

    func sectionAt(_ index: Int) -> CollectionSection? {
        guard index < state.sections.count else {
            return nil
        }
        return state.sections[index]
    }

    @objc func handleRefresh() {
        refreshHandler?()
    }
}

// MARK: - UICollectionViewDataSource

extension CollectionViewDataSource: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        state.sections.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sectionAt(section)?.items.count ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let item = itemAt(indexPath) else {
            return UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: item.cellIdentifier, for: indexPath)
        item.configure(cell)

        if shouldLoadMore(at: indexPath) {
            loadMoreHandler?(indexPath.item)
        }

        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let section = sectionAt(indexPath.section) else {
            return UICollectionReusableView()
        }

        let supplementaryItem: (any SupplementaryViewItem)?

        switch kind {
        case UICollectionView.elementKindSectionHeader:
            supplementaryItem = section.headerItem
        case UICollectionView.elementKindSectionFooter:
            supplementaryItem = section.footerItem
        default:
            supplementaryItem = nil
        }

        guard let item = supplementaryItem else {
            return UICollectionReusableView()
        }

        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                   withReuseIdentifier: item.viewIdentifier,
                                                                   for: indexPath)

        item.configure(view)
        return view
    }
}

// MARK: - UICollectionViewDelegate

extension CollectionViewDataSource: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let item = itemAt(indexPath) else {
            return
        }
        selectionHandler?.handle(item: item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension CollectionViewDataSource: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        sectionAt(section)?.sectionInsets ?? .zero
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        sectionAt(section)?.minimumLineSpacing ?? 0
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        sectionAt(section)?.minimumInteritemSpacing ?? 0
    }
}
