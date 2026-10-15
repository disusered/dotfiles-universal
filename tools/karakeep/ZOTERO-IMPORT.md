# Zotero import

`python3 scripts/import-zotero.py --state-dir PRIVATE_DIRECTORY` previews an
inspected staging inventory. Add `--execute` only for an authorized import;
`--validate` rechecks records and downloads uploaded assets without writes.
The program uses Python's standard library and the existing private Karakeep
`api.env`; it refuses any account other than `carlos@disusered.com`.

The staging directory must be private (0700), with `inventory.json` holding
`{userId, items, collections}` from all pages of Zotero Web API v3 personal
`/items` and `/collections` (not `/items/trash`). `downloads.json` maps Zotero
attachment keys to `{path, sha256, zip}`. Stage the native `/items/KEY/file`
responses with the existing Personal/Zotero API Key and userID read into memory.
Never pass keys on command lines or send the Zotero key to redirected file hosts.
No part of this importer writes to Zotero.

## Mapping and recovery

- Source URLs become Karakeep links; existing exact URLs are reused.
- PDFs and images become asset bookmarks using downloaded bytes.
- A source's saved HTML becomes a precrawled archive. A reused link receives the
  snapshot as an additional uploaded asset, preserving its current capture.
- Single-HTML ZIP transport responses are unpacked in memory. Multi-file ZIPs
  require a separately reviewed conversion; the importer refuses to discard files.
- Original item metadata, including source dates, creators, relations, tags, and
  Zotero keys, remains verbatim JSON in the bookmark note. Existing notes survive.
- Collections become nested lists; tags remain tags. Attachment membership also
  inherits its parent's collections.
- Bookmark notes carry deterministic provenance markers. Receipt IDs, markers,
  and exact URL lookup prevent duplicate bookmarks during a rerun.
- Private `receipt.json` records uploads immediately and each bookmark before
  subsequent list/tag mutations. Keep the staging directory for resume/review.
  An interruption between server upload and receipt persistence can leave an
  unattached asset; it does not create a duplicate source bookmark.

Do not treat an HTTP create response as archival proof. Validation reads every
bookmark and readable content, records actual crawl status and archive IDs, and
retrieves all imported file assets to compare SHA-256 against staged bytes.
Crawler work is asynchronous: rerun `--validate` after processing settles.
`validation.json` and individual readback files stay private, outside Git.
A full-page archive ID establishes its association, not usable archive content;
check archive retrieval and content separately before claiming full preservation.
The `archived` inbox flag is unrelated and is never set by this importer.

## Initial inventory (2026-09-29)

34 Zotero items: 21 webpages, 1 journal article, 7 PDFs, 5 HTML snapshots;
4 collections; no notes or annotations. All 12 attachments downloaded.
Expected mapping: 29 bookmarks and five preserved snapshots attached to parents.
All three ZIP responses contain exactly one HTML file; two snapshots are raw HTML.

## Validation completed (2026-09-29)

The authorized first run imported all 34 records as 29 bookmarks: 22 links and
7 PDFs, with 5 saved HTML snapshots on parent links and 4 collection lists.
All 12 uploaded files were downloaded back with matching SHA-256 hashes.
The actual second run retained the same 30 total account bookmarks (29 imports
plus the pre-existing test) and exactly the same notes and IDs.

After processing, 21 links succeeded and one source refused the crawler with
HTTP 403; that item had no existing saved Zotero attachment. Metadata remains,
but its article text is not preserved. There are no pending jobs from the import.
All seven PDFs have searchable text. One 27-page scanned PDF required separate
full-document Tesseract OCR because Karakeep's default result covered only a
short preview. Its `assetContent` was patched through the supported API, leaving
the original PDF and note unchanged; a page-20 phrase was found via search.
Nonempty extracted text alone does not prove full-document OCR.

One large article repeatedly timed out while bundling external media. Its original
HTML was fetched, checksummed, attached to the existing bookmark as
`precrawledArchive`, and processed successfully through the owner-scoped
`bookmarks.recrawlBookmark` tRPC operation. This snapshot preserves source text
but references external images/styles rather than bundling them. Its note and
receipt explicitly record that limitation. No duplicate bookmark was created.

Private evidence is preserved in
`~/.local/share/karakeep/data/imports/zotero-20260929`: `receipt.json` accounts
for all records and preserves OCR/recovery provenance; `detailed-validation.json`
contains final crawl, extraction, list/tag, and archive readback evidence;
`resume-validation.json`, `search-validation.json`, `ocr-validation.json`, and
`ocr-search-validation.json` record the targeted checks. This directory is included in the Karakeep data backup.
Zotero remained unchanged throughout.
