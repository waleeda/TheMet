# The Met Collection Swift Package

A lightweight Swift package for interacting with The Metropolitan Museum of Art Collection API. It provides async helpers for discovering all object identifiers and streaming detailed records so an iPhone app can work with the museum's 400,000+ works of art.

## Usage

Add the package dependency in Xcode or to your `Package.swift`:

```swift
.package(url: "https://github.com/your-org/TheMet.git", from: "1.0.0")
```

Import and stream objects:

```swift
import TheMet

let client = MetClient()

for try await object in client.allObjects(concurrentRequests: 8) {
    print(object.title ?? "Untitled")
}
```

Filter object identifiers using optional parameters:

```swift
let ids = try await client.objectIDs(for: ObjectQuery(departmentIds: [6], hasImages: true)).objectIDs
```

`allObjects` fetches the full list of identifiers first and then downloads detailed records in configurable parallel batches, making it suitable for downloading the full collection for offline analysis or caching.

Fetch departments or search directly:

```swift
let departments = try await client.departments()
let searchResults = try await client.search(SearchQuery(searchTerm: "flowers", departmentId: 5, hasImages: true))
```
