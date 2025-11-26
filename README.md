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

You can also reuse search-style filters on the lighter objects endpoint without switching query types:

```swift
let query = ObjectQuery(
    searchQuery: "flowers",
    isHighlight: true,
    medium: "Oil",
    dateBegin: 1800,
    dateEnd: 1900
)

let highlightedPaintings = try await client.objectIDs(for: query).objectIDs
```

`allObjects` fetches the full list of identifiers first and then downloads detailed records in configurable parallel batches, making it suitable for downloading the full collection for offline analysis or caching.

You can also monitor progress or cancel long-running streams. The streaming helpers accept a `progress` callback and an optional `CooperativeCancellation` so you can stop fetching when your UI dismisses:

```swift
var shouldCancel = false

for try await object in client.allObjects(
    concurrentRequests: 8,
    progress: { progress in
        print("Finished \(progress.completed) of \(progress.total)")
    },
    cancellation: CooperativeCancellation { shouldCancel }
) {
    if object.objectID == 1000 { shouldCancel = true }
}
```

Fetch departments or search directly:

```swift
let departments = try await client.departments()
let searchResults = try await client.search(SearchQuery(searchTerm: "flowers", departmentId: 5, hasImages: true))

let suggestions = try await client.autocomplete("sun")
let related = try await client.relatedObjectIDs(for: 123).objectIDs
let galleryNumber = try await client.object(id: 123).galleryNumber
```

The `galleryNumber` property on `MetObject` is useful when you want to point visitors to a specific room in the building—perfect for National Gallery-style walkthroughs and wayfinding views in your app.

### Custom JSON decoding strategies

If your project requires specific decoding behavior (for example, ISO 8601 dates or custom floating-point formatting), you can configure the decoder used by `MetClient` without building it yourself:

```swift
let client = MetClient(
    decodingStrategies: .init(
        dateDecodingStrategy: .iso8601,
        nonConformingFloatDecodingStrategy: .convertFromString(
            positiveInfinity: "INF",
            negativeInfinity: "-INF",
            nan: "NaN"
        )
    )
)

let ids = try await client.objectIDs(for: ObjectQuery(hasImages: true))
```
