# Product — Queries

Query parameters, filters, sorting, pagination and partial update. Shared by
node-express and ruby-sinatra.

## Schema

```mermaid
erDiagram
    products {
        integer  id          PK "autoincrement; tie-breaker of every sort"
        string   name        "NOT NULL, 2-100 chars"
        text     description "nullable, max 1000 chars"
        string   category    "NOT NULL, 2-50 chars"
        decimal  price       "NOT NULL, DECIMAL(10,2), 0 to 99999999.99; returned as text"
        datetime created_at  "NOT NULL"
        datetime updated_at  "NOT NULL"
    }
```

`price` is **text on the wire**: sent as a JSON string or number, always
returned as a string (`"159.9"`), so no client ever loses precision to a float.

### Accepted fields

`POST` and `PATCH` accept `name, description, category, price`; `POST` requires
`name`, `category` and `price`. Unknown keys are a `400` (`Unknown fields`)
before the model sees them.

## Query pipeline

`GET /products` runs the stages below in order; an invalid parameter stops the
request with a `400` naming it.

```mermaid
flowchart TD
    A[GET /products] --> B["All products"]
    B --> C{category<br/>String, max 50?}
    C -- ok --> D[where category: value]
    C -- invalid --> Z[400 Invalid parameter]
    D --> E{min_price / max_price<br/>decimal?}
    E -- ok --> F["where price: gte / lte<br/>(inclusive)"]
    E -- invalid --> Z
    F --> G{"sort in allowlist?<br/>optional '-' prefix"}
    G -- ok --> H["orderBy: column<br/>id breaks ties"]
    G -- invalid --> Z
    H --> I{page / limit<br/>positive integers?}
    I -- ok --> J["skip / offset<br/>take / limit: 1..100, default 10"]
    I -- invalid --> Z
    J --> K[["{ products: [...],<br/>pagination: { page, limit, total } } 200"]]
```

### Parameters

| Parameter | Type | Default | Rules |
| --- | --- | --- | --- |
| `category` | text | — | Exact match; at most 50 characters |
| `min_price` | decimal | — | Inclusive lower bound; a decimal number (`10`, `10.5`, `.5`, `-3`) |
| `max_price` | decimal | — | Inclusive upper bound; same format |
| `sort` | string | `id` | One of `id`, `name`, `price`, `category`, `created_at`; a leading `-` means descending (`-price`) |
| `page` | integer | `1` | Positive integer, 1-based |
| `limit` | integer | `10` | Positive integer, at most `100` (`MAX_LIMIT`) |

- Sorting always adds `id`, so pages are **stable** — walking them never
  skips nor repeats a record.
- `pagination.total` is the count **after** filters and **before** skip/take
  (or offset/limit).

## Routes

| Method | Path | Success | Notes |
| --- | --- | --- | --- |
| `GET` | `/products` | `200` | `{ "products": [...], "pagination": { page, limit, total } }` |
| `GET` | `/products/:id` | `200` | `{ "product": {...} }` |
| `POST` | `/products` | `201` | `Location: /products/:id` |
| `PATCH` | `/products/:id` | `200` | Only the sent fields change |

Entity-specific code beyond the shared ones (defined in
[errors.md](../errors.md)): none — every response here is shared.

## Examples

### List with filter, sorting and pagination

```http
GET /products?category=peripherals&min_price=10&sort=-price&page=2&limit=5
```

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "products": [
    {
      "id": 8,
      "name": "Keyboard",
      "description": "nice",
      "category": "peripherals",
      "price": "159.9",
      "created_at": "2026-10-03T21:22:40.938Z",
      "updated_at": "2026-10-03T21:22:40.938Z"
    }
  ],
  "pagination": { "page": 2, "limit": 5, "total": 42 }
}
```

### Create

```http
POST /products
Content-Type: application/json

{ "name": "Keyboard", "category": "peripherals", "price": "159.9" }
```

```http
HTTP/1.1 201 Created
Location: /products/8
Content-Type: application/json

{ "product": { "id": 8, "name": "Keyboard", "description": null, "category": "peripherals", "price": "159.9", "created_at": "...", "updated_at": "..." } }
```

### Partial update

```http
PATCH /products/8
Content-Type: application/json

{ "price": "149.9" }
```

Only `price` changes; `updated_at` is refreshed.

### Invalid parameter

```http
GET /products?sort=stock
```

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "Invalid parameter",
  "messages": ["sort must be one of: id, name, price, category, created_at"]
}
```

## Notes

- An unknown `sort` column is a `400`, never silently ignored — the allowlist
  keeps column names out of the query unchecked.