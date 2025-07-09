# 📦 DataSource

**DataSource** is a lightweight and modular Swift package designed to simplify `UITableView` and `UICollectionView` data handling. It provides built-in support for pagination, refreshing, empty and error states, while embracing Swift Concurrency and Combine.

---

## ✅ Features

- ✅ Unified data handling for `UITableView` and `UICollectionView`
- 🔄 Supports **pagination**, **refreshing**, and **loading more**
- 📡 Reactive updates via **Combine** and **AsyncStream**
- 🧱 Strongly typed cell/section abstractions
- ⚠️ Built-in support for **empty** and **error** UI states
- 🧪 Easy to test and mock

---

## 🧱 Architecture Overview

```
TableViewDataSource / CollectionViewDataSource
└── State Enum (loading, loaded, error, empty, etc.)
    └── Sections and Pagination
```

---

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bamohammad/dataSource.git", from: "1.0.0"),
```
---

## 📋 Usage

### ✅ Table View

```swift
let dataSource = TableViewDataSourceFactory.makeDataSource()
dataSource.attach(to: tableView)

dataSource.send(.loading())
dataSource.update(sections: [DefaultSection(items: yourItems)], pagination: .initial)
```

### ✅ Collection View

```swift
let dataSource = CollectionViewDataSourceFactory.makeDataSource()
dataSource.attach(to: collectionView)

dataSource.send(.loading())
dataSource.update(sections: [DefaultCollectionSection(items: yourItems)], pagination: .initial)
```

---

## 🔧 Cell Configuration

### Table View

```swift
struct MyItem { let title: String }

final class MyCell: UITableViewCell, ConfigurableTableCell {
    func configure(with item: MyItem) {
        textLabel?.text = item.title
    }
}

let item = CellItemFactory.make(cellType: MyCell.self, item: MyItem(title: "Example"))
```

### Collection View

```swift
final class MyCell: UICollectionViewCell, ConfigurableCollectionCell {
    func configure(with item: MyItem) {
        // configure UI
    }
}

let item = CollectionCellItemFactory.make(cellType: MyCell.self, item: MyItem(title: "Item"))
```

---

## 📡 Reactive Bindings

### Combine

```swift
dataSource.statePublisher
    .sink { state in
        // react to state
    }
    .store(in: &cancellables)
```

### AsyncStream

```swift
Task {
    for await state in dataSource.observeState() {
        // react to state
    }
}
```

---

## 🧭 Supported States

- `.initial`
- `.loading(previousSections:)`
- `.refreshing(currentSections:)`
- `.loadingMore(currentSections:, pagination:)`
- `.loaded(sections:, pagination:)`
- `.empty(config:)`
- `.error(error:, previousSections:)`
- `.loadingMoreError(error:, currentSections:, pagination:)`

---

## ⚙️ Configuration

```swift
let config = TableViewDataSource.Configuration(
    loadingHeaderHeight: 50,
    showLoadingFooter: true,
    emptyStateViewProvider: { config in
        let view = UIView()
        view.backgroundColor = config.backgroundColor
        return view
    }
)
```

---

## 🧱 Components

| Component                      | Description                                      |
|-------------------------------|--------------------------------------------------|
| `TableViewDataSource`         | UIKit table view handler                         |
| `CollectionViewDataSource`    | UIKit collection view handler                    |
| `PaginationInfo`              | Holds page info and `hasMorePages`              |
| `ViewError`                   | Error with optional underlying reason            |
| `EmptyStateConfiguration`     | Custom empty view data (title, image, color)     |
| `CellItemFactory`             | Factory for table/collection cell items          |
| `SupplementaryViewFactory`    | Factory for header/footer views in collections   |

---

## 📱 Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15+

---

## 📄 License

This package is released under the [MIT License](./LICENSE).

---

## ✨ Contribution

Feel free to open issues or submit pull requests! Feedback and contributions are welcome.

---

> Designed by [Ali Bamohammad](https://github.com/bamohammad) with ❤️
