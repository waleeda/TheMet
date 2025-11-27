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

You can also compose filters with the `MetFilter` enum and reuse them across endpoints:

```swift
let filters: [MetFilter] = [
    .searchTerm("flowers"),
    .departmentId(5),
    .hasImages(true),
    .dateBegin(1800),
    .dateEnd(1900)
]

let filteredIDs = try await client.objectIDs(using: filters).objectIDs
let searchResults = try await client.search(using: filters).objectIDs
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

Retry attempts triggered by 429 or 5xx responses (or transient transport errors) can be surfaced to your UI via the `onRetry` callback. This enables lightweight toasts or metrics so users know downloads are still progressing:

```swift
let client = MetClient(onRetry: { event in
    print("Retry #\(event.attempt) in \(event.delay)s due to \(event.reason)")
})
```

Fetch departments or search directly:

```swift
let departments = try await client.departments()
let searchResults = try await client.search(SearchQuery(searchTerm: "flowers", departmentId: 5, hasImages: true))

let suggestions = try await client.autocomplete("sun")
let related = try await client.relatedObjectIDs(for: 123).objectIDs
```

## National Gallery of Art collection support

The package also includes a lightweight `NationalGalleryClient` for the National Gallery of Art Collection API. The API surface mirrors the Met helper methods so you can search for objects and fetch details with familiar patterns:

```swift
import TheMet

let nga = NationalGalleryClient()
let landscapes = try await nga.objectIDs(for: NationalGalleryObjectQuery(keyword: "landscape", hasImages: true, page: 1, pageSize: 25)).objectIDs
let object = try await nga.object(id: landscapes.first ?? 0)
print(object.title ?? "Untitled")
```

Stream the entire National Gallery of Art collection with familiar cancellation and progress hooks:

```swift
let client = NationalGalleryClient()

for try await object in client.allObjects(pageSize: 100, concurrentRequests: 4, progress: { progress in
    print("Finished \(progress.completed) of \(progress.total)")
}) {
    print(object.title ?? "Untitled")
}
```

## Smithsonian Open Access (EDAN/CC0) support

Browse image-first Smithsonian records using the `SmithsonianClient`. CC0 media is enabled by default and you can facet by topic, place, or date directly in the search query:

```swift
import TheMet

let smithsonian = SmithsonianClient()

let response = try await smithsonian.search(
    SmithsonianSearchQuery(
        searchTerm: "pottery",
        topic: "Ceramics",
        place: "Peru",
        date: "1200",
        rows: 20
    )
)

guard let first = response.rows.first else { return }
print(first.title ?? "Untitled")
print(first.media.first?.bestURL?.absoluteString ?? "No media")
```

### Cross-museum browsing

Prefer a single toggle between the Met and the National Gallery of Art? Use `CrossMuseumClient` to pick a source while keeping a consistent API for listing IDs, searching, fetching objects, or streaming entire collections:

```swift
import TheMet

var client = CrossMuseumClient()

// Start with The Met
let metSearch = try await client.search(.met(SearchQuery(searchTerm: "sunflowers")))
print(metSearch.objectIDs)

// Toggle to the National Gallery of Art
client.source = .nationalGallery
let ngaIDs = try await client.objectIDs(for: .nationalGallery(.init(hasImages: true, pageSize: 10)))
print(ngaIDs.total)

// Stream objects from the active museum
for try await object in client.allObjects(concurrentRequests: 4, progress: { progress in
    print("Finished \(progress.completed) of \(progress.total)")
}) {
    print(object)
}
```

## Harvard Art Museums support

The package also ships with a `HarvardArtMuseumsClient` that mirrors the convenience of the other clients while exposing Harvard-specific filters for culture, period, and classification. Provide your Harvard API key and reuse the familiar departments and objects endpoints:

```swift
import TheMet

let harvard = HarvardArtMuseumsClient(apiKey: "YOUR_API_KEY")
let ids = try await harvard.objectIDs(for: HarvardObjectQuery(culture: "Chinese", classification: "Prints", hasImage: true)).objectIDs
let departments = try await harvard.departments()
let object = try await harvard.object(id: ids.first ?? 0)
```

You can stream Harvard objects with cancellation and progress callbacks just like the other clients:

```swift
for try await object in harvard.allObjects(query: HarvardObjectQuery(period: "Renaissance"), pageSize: 50, concurrentRequests: 4, progress: { progress in
    print("Finished \(progress.completed) of \(progress.total)")
}) {
    print(object.title ?? "Untitled")
}
```

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
