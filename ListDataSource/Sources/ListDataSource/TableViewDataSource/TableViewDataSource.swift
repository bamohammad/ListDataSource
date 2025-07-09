//
//  TableViewDataSource.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//

import Combine
import UIKit

// MARK: - Data Source Configuration

public extension TableViewDataSource {
    struct Configuration {
        public var loadingHeaderHeight: CGFloat = 44
        public var loadingFooterHeight: CGFloat = 44
        public var showLoadingHeader: Bool = true
        public var showLoadingFooter: Bool = true
        public var emptyStateViewProvider: ((EmptyStateConfiguration) -> UIView)?

        public init() {}

        public static var `default`: Configuration {
            Configuration()
        }
    }
}

// MARK: - Table View Data Source

@MainActor
public final class TableViewDataSource: NSObject {
    // MARK: - Types

    public typealias LoadMoreHandler = @Sendable (Int) -> Void
    public typealias RefreshHandler = @Sendable () -> Void

    // MARK: - Properties

    private var state: TableViewState
    private let selectionHandler: TableSelectionHandler?
    private weak var tableView: UITableView?
    private let configuration: Configuration

    private var loadMoreHandler: LoadMoreHandler?
    private var refreshHandler: RefreshHandler?

    // MARK: - AsyncStream Support

    private var asyncContinuation: AsyncStream<TableViewState>.Continuation?
    private lazy var asyncUpdates: AsyncStream<TableViewState> = AsyncStream { self.asyncContinuation = $0 }

    public var stateStream: AsyncStream<TableViewState> {
        asyncUpdates
    }

    // MARK: - Combine Support

    private let stateSubject = CurrentValueSubject<TableViewState, Never>(.initial)
    private var cancellables = Set<AnyCancellable>()

    public var statePublisher: AnyPublisher<TableViewState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var sectionsPublisher: AnyPublisher<[TableSection], Never> {
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

    // MARK: - Lazy Properties

    private lazy var loadingFooterView: UIView? = {
        guard configuration.showLoadingFooter else {
            return nil
        }
        return createLoadingView(height: configuration.loadingFooterHeight)
    }()

    private lazy var loadingHeaderView: UIView? = {
        guard configuration.showLoadingHeader else {
            return nil
        }
        return createLoadingView(height: configuration.loadingHeaderHeight)
    }()

    // MARK: - Initialization

    public init(initialState: TableViewState = .initial,
                selectionHandler: TableSelectionHandler? = nil,
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

public extension TableViewDataSource {
    func attach(to tableView: UITableView,
                loadMore: LoadMoreHandler? = nil,
                refresh: RefreshHandler? = nil) {
        self.tableView = tableView
        loadMoreHandler = loadMore
        refreshHandler = refresh

        tableView.dataSource = self
        tableView.delegate = self

        setupRefreshControl(for: tableView)
    }

    func send(_ newState: TableViewState) {
        state = newState

        // Send to both AsyncStream and Combine
        asyncContinuation?.yield(newState)
        stateSubject.send(newState)
    }

    func update(sections: [TableSection], pagination: PaginationInfo? = nil) {
        let newState: TableViewState = sections.isEmpty
            ? .empty(config: .init())
            : .loaded(sections: sections, pagination: pagination)
        send(newState)
    }
}

// MARK: - AsyncStream Convenience Methods

public extension TableViewDataSource {
    func observeState() -> AsyncStream<TableViewState> {
        stateStream
    }

    func observeSections() -> AsyncStream<[TableSection]> {
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

public extension TableViewDataSource {
    func bindToViewModel<VM: ObservableObject>(_ viewModel: VM,
                                               stateKeyPath: ReferenceWritableKeyPath<VM, TableViewState>) -> AnyCancellable {
        statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: stateKeyPath, on: viewModel)
    }

    func bindSections<VM: ObservableObject>(to viewModel: VM,
                                            keyPath: ReferenceWritableKeyPath<VM, [TableSection]>) -> AnyCancellable {
        sectionsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: viewModel)
    }
}

// MARK: - Private Methods

private extension TableViewDataSource {
    func setupUpdateHandling() {
        statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.handleUpdate(newState)
            }
            .store(in: &cancellables)
    }

    func setupRefreshControl(for tableView: UITableView) {
        guard refreshHandler != nil else {
            return
        }

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    func createLoadingView(height: CGFloat) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height))
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
        return view
    }

    func handleUpdate(_ newState: TableViewState) {
        let oldState = state
        state = newState

        updateLoadingViews()
        updateEmptyState()
        updateRefreshControl(from: oldState)
        reloadTableView()
    }

    func updateLoadingViews() {
        switch state.loadingState {
        case .loading:
            tableView?.tableHeaderView = loadingHeaderView
            tableView?.tableFooterView = nil
        case .loadingMore:
            tableView?.tableHeaderView = nil
            tableView?.tableFooterView = loadingFooterView
        default:
            tableView?.tableHeaderView = nil
            tableView?.tableFooterView = nil
        }
    }

    func updateEmptyState() {
        if case let .empty(config) = state,
           let provider = configuration.emptyStateViewProvider {
            tableView?.backgroundView = provider(config)
        } else {
            tableView?.backgroundView = nil
        }
    }

    func updateRefreshControl(from oldState: TableViewState) {
        if case .refreshing = oldState {
            tableView?.refreshControl?.endRefreshing()
        }
    }

    func reloadTableView() {
        tableView?.reloadData()
    }

    func shouldLoadMore(at index: Int) -> Bool {
        guard let pagination = state.pagination,
              pagination.hasMorePages,
              !state.loadingState.isLoading else {
            return false
        }

        return true
    }

    func itemAt(_ indexPath: IndexPath) -> (any TableCellItem)? {
        guard indexPath.section < state.sections.count,
              indexPath.row < state.sections[indexPath.section].items.count else {
            return nil
        }
        return state.sections[indexPath.section].items[indexPath.row]
    }

    func sectionAt(_ index: Int) -> TableSection? {
        guard index < state.sections.count else {
            return nil
        }
        return state.sections[index]
    }

    @objc func handleRefresh() {
        refreshHandler?()
    }
}

// MARK: - UITableViewDataSource

extension TableViewDataSource: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        state.sections.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sectionAt(section)?.items.count ?? 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = itemAt(indexPath) else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: item.cellIdentifier, for: indexPath)
        item.configure(cell)

        if shouldLoadMore(at: indexPath.row) {
            loadMoreHandler?(indexPath.row)
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension TableViewDataSource: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = itemAt(indexPath) else {
            return
        }
        selectionHandler?.handle(item: item)
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        sectionAt(section)?.headerView(for: tableView, at: section)
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        sectionAt(section)?.footerView(for: tableView, at: section)
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let section = sectionAt(section) else {
            return CGFloat.leastNonzeroMagnitude
        }
        // Use 44.0 as default instead of UITableView.automaticDimension to avoid MainActor issues
        let height = section.headerHeight
        return height == 0 ? 44.0 : height
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let section = sectionAt(section) else {
            return CGFloat.leastNonzeroMagnitude
        }
        // Use 44.0 as default instead of UITableView.automaticDimension to avoid MainActor issues
        let height = section.footerHeight
        return height == 0 ? 44.0 : height
    }

    public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sectionAt(section)?.footerTitle
    }
}



