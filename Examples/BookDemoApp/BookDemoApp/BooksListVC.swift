//
//  BooksListVC.swift
//  BookDemoApp
//
//  Created by Ali Bamohammad on 09/07/2025.
//

import Combine
import UIKit
import ListDataSource


final class BooksListVC: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet private var contentView: BooksListView!

    // MARK: - Dependencies
    private let viewModel: BooksListVM = BooksListVM()
    private lazy var dataSource = TableViewDataSourceFactory.makeDataSource()

    // MARK: - State
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        Task { await viewModel.loadData() }
    }

    // MARK: - UI
    private func setupUI() {
        contentView.setupView()

        // Attach DataSource
        dataSource.attach(
            to: contentView.tableView,
            loadMore: { [weak self] index in
                Task { await self?.viewModel.loadMoreIfNeeded(currentIndex: index) }
            },
            refresh: { [weak self] in
                Task { await self?.viewModel.refresh() }
            }
        )
    }

    private func bindViewModel() {
        viewModel.dataSourceStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.dataSource.send(state)
            }
            .store(in: &cancellables)
    }

}
