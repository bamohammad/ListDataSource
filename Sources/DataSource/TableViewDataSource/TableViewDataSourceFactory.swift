//
//  TableViewDataSourceFactory.swift
//  DataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

@MainActor
public enum TableViewDataSourceFactory {
    public static func makeDataSource(selectionHandler: TableSelectionHandler? = nil,
                                      configuration: TableViewDataSource.Configuration = .default) -> TableViewDataSource {
        TableViewDataSource(selectionHandler: selectionHandler,
                            configuration: configuration)
    }
}
