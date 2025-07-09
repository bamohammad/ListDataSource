//
//  BooksListView.swift
//  BookDemoApp
//
//  Created by Ali Bamohammad on 09/07/2025.
//

import UIKit

final class BooksListView: UIView {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var containerView: UIView!

    // MARK: - Setup

    func setupView() {
        let nib = UINib(nibName: "BookCell", bundle: .main)
        tableView.register(nib, forCellReuseIdentifier: "BookCell")
    }
}
