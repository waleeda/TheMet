# API routes

The Swift client wraps The Met Collection API with lightweight helpers and adds in-memory caching for frequent reads. The most commonly used routes are:

- `GET /departments`: cached in memory; pass `cachePolicy: .reload` or the `cacheBust` query parameter to force refreshes.
- `GET /objects/{id}`: cached in an LRU cache of recent lookups; use `cachePolicy: .reload` to bypass the cache or add `cacheBust` in the query string.
- `GET /search`: validates filters before issuing the request and exposes a paginated helper so callers can supply `page` and `pageSize` while receiving `hasNextPage` metadata.

## Filter validation

The `SearchQuery` type ensures that provided filters are well-formed:

- `q` (search term) must not be empty.
- `isOnView` and `hasImages` are passed through as booleans when provided.
- `medium` must include non-whitespace characters when present.
- `dateBegin`/`dateEnd` must respect chronological order.
- Pagination helpers enforce positive `page` and `pageSize` values.

Invalid filters throw `SearchQueryValidationError` before any network calls are made.

## Normalized responses

Use `MetObjectSerializer.normalize(_:)` to convert raw objects into a shape that surfaces the core presentation fields: IDs, titles, dates, primary images, constituent metadata, and tags.

## Pagination helpers

Call `search(_:page:pageSize:)` to receive a `PaginatedObjectIDsResponse` structure. The response mirrors the flows documented in `docs/met_collection_api.md` with `total`, the current slice of `objectIDs`, and a `hasNextPage` flag to simplify pagination in UIs.

## Rate limits

The Met API enforces rate limits on heavy usage. The client surfaces retry callbacks for 429/5xx responses via the `onRetry` handler so you can display backoff information or slow request bursts when limits are encountered.

## Examples

```swift
let client = MetClient()
let departments = try await client.departments()
let featured = try await client.object(id: 123)

let page = try await client.search(
    SearchQuery(searchTerm: "pottery", hasImages: true, medium: "Ceramics"),
    page: 1,
    pageSize: 10
)

if page.hasNextPage {
    let next = try await client.search(SearchQuery(searchTerm: "pottery", hasImages: true, medium: "Ceramics"), page: 2, pageSize: 10)
    print(next.objectIDs)
}
```
