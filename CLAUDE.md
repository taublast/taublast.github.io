# Repo Instructions (taublast.github.io)

## Writing Style

Before drafting or editing any blog post or draft in this repo, read and follow:

- [WRITING_STYLE_GUIDE.md](WRITING_STYLE_GUIDE.md)

Use it as the source of truth for:
- voice/tone and structure
- how to frame comparisons (keep it technical/professional)
- chronology/cross-link rules (don’t imply future posts are already published)
- grounding/verification checklist (names/strings/counts must match source)

## Translation Style

Before translating any blog post, draft, or article fragment in this repo, read and follow:

- [WRITING_STYLE_GUIDE.md](WRITING_STYLE_GUIDE.md)
- [TRANSLATION_STYLE_GUIDE.md](TRANSLATION_STYLE_GUIDE.md)

Use the translation guide as the source of truth for:
- what must remain equivalent to the source article
- what may be adapted for fluency
- what kinds of additions or rewrites are not allowed during translation
- how to preserve technical accuracy, chronology, and article structure

Default translation mode in this repo is faithful technical translation, not silent adaptation or rewrite.

Create translated articles only inside `_drafts`, never directly inside `_posts`.

Translated filenames must end with a language code using a hyphen suffix, for example `-ru.md`, not `_ru.md`.

Translated files must not contain CSS styles.

For translated files, videos must be embedded using `iframe` markup following the repo examples, not raw `video` tags.

For translated files, `iframe` video links and body image links must use direct absolute URLs on the deployed site, for example `https://taublast.github.io/assets/vids/file.mp4` and `https://taublast.github.io/assets/img/file.png`, not relative asset paths.

If the user provides feedback about what went wrong in a translation, what drifted, or what should be handled differently next time, update [TRANSLATION_STYLE_GUIDE.md](TRANSLATION_STYLE_GUIDE.md) with that new repo-specific guidance when it is generalizable.

Do not leave translation corrections only in chat context if they represent a repeatable rule for future work.

If a request conflicts with the style guide, ask for clarification.
