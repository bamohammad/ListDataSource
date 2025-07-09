//
//  CollectionViewDataSourceFactory.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

@MainActor
public enum CollectionViewDataSourceFactory {
    public static func makeDataSource(
        selectionHandler: CollectionSelectionHandler? = nil,
        configuration: CollectionViewDataSource.Configuration = .default
    ) -> CollectionViewDataSource {
        CollectionViewDataSource(
            selectionHandler: selectionHandler,
            configuration: configuration
        )
    }
}
