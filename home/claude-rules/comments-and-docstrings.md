# Comments and docstrings

Write comments for the future reader of the file, who has no access to this
conversation, the PR, or earlier drafts. Never write them for the reviewer
of the current change.

- If understanding a comment requires PR history, delete it. Never reference
  earlier drafts ("subsumes the old X", "renamed from Y", "we now do Z"),
  alternatives you didn't take, or the fact that something changed.
- Comment the *why* the code can't express: invariants, ordering constraints,
  error-severity choices, gotchas (e.g. "tinyint, not bool"). Don't restate
  what the code does, don't justify the design to an imagined skeptic, and
  don't editorialize ("this is the test that earns its keep").
- State what a thing is or does — its essence — not what it's used for, who
  calls it, or where related work happens. Don't explain what the language
  already guarantees, don't restate the signature, and don't comment a function
  short enough to just read.
- Describe behavior generally; don't enumerate specific instances of it. Drop
  redundant qualifiers.
- Each fact lives in exactly one place — the symbol that owns it. Module
  docstrings: ≤4 lines of what + entrypoint pointer; don't duplicate
  per-symbol docstrings or write "Design:" sections (that's the PR
  description's job).
- After any rename or refactor, sweep comments/docstrings for stale names
  and dead references — comments are code and can be wrong.
- No markdown emphasis (**bold**) in docstrings; no comments that only make
  sense while the diff is open.

Litmus test: would this comment still be true and useful, and is it the
shortest form that's still both, to someone reading the file in two years with
no context? If not, cut it.
