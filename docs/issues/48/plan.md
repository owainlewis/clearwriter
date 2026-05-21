# Plan for Issue #48: Add 'Copy as Markdown' action to document menu

## Source Issue

- URL: https://github.com/owainlewis/clearwriter/issues/48
- Number: #48

## Summary

Add a “Copy as Markdown” action to document action menus so users can copy the raw markdown body to the clipboard from both the editor and preview/share views.

## Goal

Users can click “Copy as Markdown” from the document ⋯ menu and get the document’s markdown source copied via the Clipboard API, with brief “Copied” confirmation feedback.

## Acceptance Criteria

- The document actions menu includes a `Copy as Markdown` item.
- Clicking it copies raw markdown, not rendered HTML.
- The action works on the editor page, including when the editor’s preview pane is visible.
- The action is available on the public preview/share page.
- The menu item briefly changes to confirmation text such as `Copied` for about 1 second.
- Existing share/unshare/delete behavior remains unchanged.

## Implementation Plan

1. Inspect existing document menu markup in `app/views/documents/edit.html.erb` and public preview markup in `app/views/public_documents/show.html.erb`.
2. Add a small Stimulus clipboard/copy controller or extend an existing appropriate controller to:
   - read markdown from the live editor textarea/source when on the edit page,
   - read/fetch raw markdown on the public preview/share page,
   - call `navigator.clipboard.writeText(...)`,
   - temporarily update the clicked button label to `Copied`.
3. Add `Copy as Markdown` button markup to the edit document actions menu, wired to the copy behavior and the current markdown source.
4. Add a matching actions menu to the public preview/share page if one is not already present, including `Copy as Markdown`.
5. Ensure any embedded markdown values are safely escaped, or prefer reading from an existing hidden textarea / fetching the `.md` public endpoint to avoid copying rendered HTML.
6. Reuse existing `.cw-menu` / `.cw-menu__item` styling so the new action matches the current UI.

## Verify

```bash
bin/rails test
bin/rubocop
bin/rails assets:precompile
```

## Evaluation Notes

The implementation review should check:

- completeness against the GitHub issue
- correctness and edge cases
- scope control
- test/verification quality
- maintainability
- PR readiness

## Out of Scope

- Copying rendered HTML.
- Export/download functionality.
- Changing markdown rendering behavior.
- Redesigning the document menu beyond adding the requested action.
