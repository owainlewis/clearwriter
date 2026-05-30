# Agent Media Assets Design

## Status

Draft.

## Summary

PAIR should add uploads as first-class `Asset` records backed by private Google Cloud Storage objects, not as opaque Rails attachments hanging off documents. Documents stay markdown-first; assets become addressable resources that humans can browse and agents can list, inspect, download through short-lived URLs, and attach to documents, collections, or tasks.

The recommended v1 upload path is direct-to-GCS resumable upload: PAIR creates an `Asset` row in `pending` state, initiates a GCS resumable upload session, returns the session URI to the browser or agent, then finalizes the asset after the client reports completion. This fits large audio/video files and avoids proxying bytes through Rails.

## Context and Scope

The current app stores documents as markdown in Postgres and exposes a clean JSON/markdown API for agents. Collections and tasks link documents rather than owning them. There is no file upload layer; `config/application.rb` has Active Storage disabled.

This design covers:

- image, audio, video, PDF, and arbitrary file uploads;
- private GCS-backed storage;
- human UI and agent API access;
- linking assets into documents, collections, and tasks;
- basic metadata and processing state.

This design does not implement full media editing, transcription, OCR, vector indexing, or a public asset CDN.

## Goals

- Keep documents markdown-first while allowing rich source material beside them.
- Make uploads useful to AI agents through stable IDs, metadata, search/list APIs, and short-lived download URLs.
- Support large files without routing upload/download bodies through Rails.
- Keep all objects private by default.
- Support future processing jobs: thumbnails, media duration, transcripts, OCR, embeddings.
- Work cleanly on Google Cloud Run with Cloud Storage and Postgres.

## Non-Goals

- No public permanent file URLs in v1.
- No collaborative media annotation UI.
- No replacement for document markdown storage.
- No generic Dropbox-style folder hierarchy.
- No strong need to use Rails Active Storage unless we later decide its conventions outweigh the need for agent-specific metadata.

## Constraints

- GCS resumable uploads are the right default for large files because interrupted transfers can resume without starting over.
- GCS resumable upload session URIs are bearer-like secrets and must be transmitted over HTTPS only.
- Signed URLs are useful for short-lived reads and simple writes, but Google’s docs note that signed URLs are generally unnecessary for resumable uploads when the server can initiate the session.
- The existing product has owner-scoped opaque public tokens and bearer-token API auth; assets should follow the same pattern.
- Cloud Run instances are ephemeral; no local disk persistence.

## Proposed Design

Introduce an `Asset` model as a sibling to `Document`, owned by a user:

- `public_token`
- `user_id`
- `filename`
- `content_type`
- `byte_size`
- `checksum`
- `kind`: `image`, `audio`, `video`, `pdf`, `archive`, `text`, `other`
- `status`: `pending`, `uploaded`, `processing`, `ready`, `failed`
- `storage_bucket`
- `storage_key`
- `metadata` JSONB: width, height, duration, page count, codec, extracted text status, thumbnail key, etc.
- `tags` array
- timestamps

Add link tables rather than direct ownership:

- `document_assets(document_id, asset_id, position, role)`
- `collection_assets(collection_id, asset_id, position)`
- `task_assets(task_id, asset_id)`

`role` on document links can support `attachment`, `inline_image`, `source`, `transcript_source`, etc. Markdown can still embed assets with ordinary generated URLs when rendering, but the database link remains the authoritative relationship.

## Upload Flow

1. Client calls `POST /api/v1/assets/uploads` with filename, content type, byte size, optional checksum, and optional context link.
2. PAIR validates limits and creates `Asset(status: pending)`.
3. PAIR chooses a storage key like:
   `users/{user_public_token}/assets/{asset_public_token}/original/{safe_filename}`
4. PAIR initiates a GCS resumable upload session for that key and content type.
5. PAIR returns:
   - `asset_id`
   - `upload_url` / session URI
   - required headers
   - `expires_at`
6. Browser or agent uploads directly to GCS using the session URI.
7. Client calls `POST /api/v1/assets/:id/complete`.
8. PAIR verifies object existence, size, content type, checksum if provided, and transitions to `uploaded`.
9. A background job extracts metadata and moves the asset to `ready` or `failed`.

For small images, this same flow is still acceptable. It avoids introducing two upload protocols early.

## Download and Access Flow

Assets are private. UI and API never expose raw `storage.googleapis.com/...` object URLs.

- `GET /api/v1/assets/:id` returns metadata.
- `POST /api/v1/assets/:id/download_url` returns a short-lived signed GET URL.
- UI image/video/audio previews use app-mediated short-lived URLs or a controller redirect to a signed URL.
- Public document sharing should not automatically expose private assets in v1. Later, shared documents can include a signed asset proxy policy.

## Agent Interfaces

Agents need predictable operations:

- `GET /api/v1/assets?kind=image&tag=lesson&q=diagram`
- `POST /api/v1/assets/uploads`
- `POST /api/v1/assets/:id/complete`
- `GET /api/v1/assets/:id`
- `POST /api/v1/assets/:id/download_url`
- `POST /api/v1/documents/:id/assets`
- `DELETE /api/v1/documents/:id/assets/:asset_id`
- equivalent collection/task asset link endpoints

Response metadata should include:

- stable `id`
- filename
- content type
- byte size
- kind
- status
- tags
- linked resources
- dimensions/duration/page count when known
- `created_at`, `updated_at`

Avoid base64 content in JSON. Agents should stream bytes to signed upload/download URLs.

## Human UI

Add an `Assets` or `Files` section in the sidebar after Documents. The first screen should be a dense media library:

- grid for images/video/PDF previews;
- list mode for arbitrary files;
- filters for kind, tag, status;
- upload button as an icon action;
- drag-and-drop upload target;
- asset detail page with preview, metadata, linked docs/tasks/collections, copy markdown reference, delete.

Document editor:

- attachment rail or menu for linked assets;
- insert markdown image/link for selected asset;
- drag image into document to upload and insert `![filename](asset://...)` or rendered app URL.

For agents, the important UI affordance is not the upload button; it is making source files visible as structured context.

## Processing Pipeline

Use background jobs after upload completion:

- identify kind from content type and magic bytes;
- generate image thumbnails;
- extract dimensions and video/audio duration;
- optionally enqueue transcription/OCR later;
- store derived files under:
  `users/{user}/assets/{asset}/derivatives/{name}`

Do not block upload completion on processing. Agents can poll `status` or inspect `metadata.processing`.

## Security

- Bucket is private. No public ACLs.
- Service account gets the minimum GCS role needed for object create/read/delete in the bucket.
- Store object keys; never trust client-provided object paths.
- Validate byte size and MIME type before issuing an upload session and again after completion.
- Use random public tokens; no sequential asset IDs in API.
- Treat upload session URIs and signed URLs as secrets.
- Keep signed download URLs short-lived.
- Add per-user max file size and storage quota.
- Consider malware scanning before assets become `ready`, especially for shared/public flows.

## Storage and Cost Controls

- Separate buckets by environment: `pair-dev-assets`, `pair-prod-assets`.
- Use lifecycle rules to delete abandoned `pending` uploads and old temporary/derived objects.
- Store originals in Standard initially; consider lifecycle transitions only once usage patterns are known.
- Track total `byte_size` per user for quotas and billing.

## Alternatives Considered

### Rails Active Storage

Pros: built-in Rails conventions, direct uploads, variants, less custom code.

Cons: weaker fit for agent-facing APIs, upload sessions, first-class metadata, status transitions, linking one asset to multiple resource types, and future processing. The app currently has Active Storage disabled, and the product model is already based on explicit link tables.

Decision: do not use Active Storage for v1 unless implementation speed becomes more important than agent ergonomics.

### Store Files Through Rails

Pros: simplest auth story and no direct browser-to-GCS CORS/session handling.

Cons: poor fit for Cloud Run, large videos/audio, slow uploads, higher memory/network pressure, worse retry behavior.

Decision: avoid proxying file bodies through Rails except maybe for tiny admin/debug paths.

### Signed PUT URLs Only

Pros: simple for small files.

Cons: less robust for large media; resumable upload is the better default for videos/audio and unreliable networks.

Decision: use resumable uploads as the main path; optionally add signed PUT later for small single-shot uploads.

## Tradeoffs

This design adds more custom code than Active Storage, but it buys a cleaner product model: files are workspace objects, not incidental blobs. That matters for agents because they need to ask “what source files are available?” and “which task/doc did this asset come from?” without reverse-engineering attachment tables.

The main risk is upload-session complexity. Keep the first implementation narrow: create, complete, list, link, download URL, delete.

## Rollout

1. Add `Asset` and link tables.
2. Add GCS config and service object.
3. Add API upload initiation and completion endpoints.
4. Add private signed download endpoint.
5. Add basic assets index/detail UI.
6. Add document/task/collection linking.
7. Add background metadata extraction.
8. Add public-share asset policy later.

## Open Questions

- What are v1 max sizes for images, audio, video, and generic files?
- Should assets be linkable to multiple documents by default? Recommended: yes.
- Should shared documents expose linked assets? Recommended v1: no, unless explicitly shared.
- Do we want transcripts stored as documents, asset metadata, or both? Recommended: transcript as a generated document linked back to the source asset.
- Should agents be allowed to upload directly via API tokens? Recommended: yes, with quota and MIME restrictions.

## Decision

Build a first-class `Asset` system backed by private GCS objects and direct resumable uploads. Keep documents markdown-native, but allow assets to be linked into documents, collections, and tasks. Expose agent-first JSON APIs for listing, upload initiation/completion, linking, and signed downloads.
