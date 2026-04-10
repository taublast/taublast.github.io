# Translation Style Guide for AI-Assisted Posts

## Purpose

This guide defines how posts in this repository should be translated from a source language into a target language.

Primary goal:
- preserve the original article's meaning, structure, technical accuracy, and author voice

Secondary goal:
- make the translated text read naturally to developers in the target language without turning the translation into a rewrite

Use this together with [WRITING_STYLE_GUIDE.md](WRITING_STYLE_GUIDE.md). The writing guide defines the author's voice. This guide defines how that voice must survive translation.

## Translation Default

Default mode for this repo is:
- **faithful technical translation**

That means:
- keep the same article structure and argument flow
- keep the same claims, scope, and emphasis
- keep the same level of confidence
- keep technical names and code exactly grounded in the source
- improve fluency, but do not introduce new positioning, new claims, or new sections unless explicitly requested

If the task is not translation but adaptation, say so explicitly in the draft or commit message using wording like:
- "translated and lightly adapted"
- "translated with regional wording adjustments"
- "localized rewrite"

Do not silently convert a translation task into an adaptation task.

## Source-First Rule

Before translating:
- read the full source article
- read [WRITING_STYLE_GUIDE.md](WRITING_STYLE_GUIDE.md)
- identify the article's core promise, section order, and technical claims
- identify any forward-looking chronology such as "next article" or "upcoming"

During translation:
- translate from the source text, not from assumptions about the project
- if the source is vague, preserve that vagueness instead of "improving" it into a stronger claim
- if the source is specific, preserve the specificity exactly

## What Must Stay Equivalent

These elements should remain semantically equivalent to the source:

- title intent and scope
- front matter meaning
- opening problem statement
- article structure and section order
- technical claims and limitations
- examples, ranges, thresholds, feature lists, and counts
- chronology and cross-links
- closing message and call to action

Equivalent does not mean literal word-for-word translation. It means a reader in the target language should come away with the same understanding as a reader of the source.

## What May Be Adapted

The following changes are acceptable when they improve readability without changing meaning:

- sentence order inside a paragraph
- idiom replacement
- punctuation and rhythm
- small wording shifts to make technical Russian, English, or other target-language phrasing sound natural
- replacing an awkward literal phrase with a natural technical phrase

Small clarifications are acceptable only when they are already implied by the source.

Example:
- source says a component is used as a hidden UI element but could also be used as a service
- translation may make that sentence smoother, but must not turn it into a different architectural recommendation

## What Must Not Be Added Without Explicit Request

Do not add any of the following unless the user explicitly asks for an adaptation or expansion:

- new editorial framing
- stronger marketing language
- competitive shots or provocative comparisons not present in the source
- extra technical claims
- extra product features
- new tips, plugins, workflows, or recommendations
- extra sections or subsections
- new conclusions or calls to action
- platform claims not made in the source

Example of drift to avoid:
- source: "single hardware-accelerated canvas"
- bad translation: expands into a broader manifesto about forgetting what people know about .NET MAUI

That changes tone, scope, and positioning.

## Tone Preservation

The translated article should sound like the same author, not like a different person.

Preserve:
- conversational but authoritative tone
- practical engineering focus
- enthusiasm grounded in implementation
- honesty about trade-offs and limitations
- developer-to-developer voice

Avoid introducing:
- slangier tone than the source
- more aggressive comparisons than the source
- dismissive language about other frameworks or stacks unless the source already uses it
- hype that exceeds the evidence shown in the article

If the source is sharp, keep it sharp.
If the source is measured, keep it measured.

## Structure Preservation

Keep the same macro-structure by default:

- translated draft filenames must end with a language code using a hyphen suffix, for example `-ru.md`
- same front matter fields
- same heading hierarchy
- same section order
- same code block placement
- same media placement unless target-language typography requires a minor layout adjustment

Do not:
- merge sections that were intentionally separate
- split sections into new subsections without reason
- move major content blocks around unless explicitly requested

If you add any translation note, place it outside the article draft, not inside the article body.

## Front Matter Rules

Front matter must remain clean and equivalent.

Translate carefully:
- `title`
- `description`

Usually keep unchanged:
- `layout`
- `date`
- `categories`
- `tags`
- `image`

Rules:
- do not leak Markdown headings into YAML
- do not invent new tags or categories during translation
- do not make the translated description broader or more sales-like than the source description
- preserve publication chronology unless explicitly instructed otherwise

## Technical Accuracy Rules

Translate technical prose conservatively.

Must remain exact:
- class names
- method names
- property names
- enum values
- file paths
- package names
- platform names
- ranges and thresholds
- quoted UI strings when they refer to actual UX text

Do not translate code identifiers.

Do not casually translate product names or library names such as:
- .NET MAUI
- DrawnUI
- SkiaCamera
- SkiaSharp
- SKSL

Translate surrounding prose, not the identifier itself.

## Code And Snippet Rules

By default:
- keep code blocks unchanged
- keep comments inside code unchanged unless the user explicitly wants localized code comments

If translating code comments is requested:
- preserve the original technical meaning exactly
- do not rewrite code structure while translating comments

When prose explains code:
- the explanation may be translated freely
- the code itself should stay source-accurate

## Links, Media, And Assets

Preserve existing links unless there is a target-language equivalent that the user explicitly wants.

Rules:
- translated files must not contain CSS styles, including inline `style` attributes or embedded style blocks
- for translated files, videos must be embedded using `iframe` markup following the repo examples
- do not use raw `video` tags in translated files unless the user explicitly asks for a different embed format
- for translated files, `iframe` video `src` values must use direct absolute URLs on the deployed site, for example `https://taublast.github.io/assets/vids/file.mp4`
- for translated files, body image `src` values must use direct absolute URLs on the deployed site, for example `https://taublast.github.io/assets/img/file.png`
- preserve alt text meaning
- preserve captions and surrounding explanatory text

If a translated draft intentionally targets a different publishing environment, note that explicitly.

## Chronology And Cross-Links

Respect time and publication status.

Do not change:
- future article references into past references
- draft references into published references
- tentative wording into confirmed wording

Use the same chronology as the source.

Examples:
- source: "in the next article" -> keep it future-oriented
- source: "later in this article" -> keep it intra-article

## Localization For Russian Technical Writing

When translating into Russian:

- prefer natural technical Russian over literal calques
- keep established English identifiers in Latin script
- translate general concepts, but keep framework/API names exact
- use transliteration sparingly and only where it reads naturally to the intended audience

Preferred pattern:
- "control" in prose may become "control", "component", or "element" depending on context
- but `SkiaControl` must remain `SkiaControl`

Avoid:
- forced slang
- casual framework put-downs not present in the source
- adding Russian-only side commentary that changes the author's posture

## Allowed Translation Moves

Good translation work often includes:

- compressing repetition that sounds awkward in the target language while keeping meaning intact
- expanding a sentence slightly to avoid ambiguity already present in literal translation
- replacing a literal metaphor with a target-language equivalent of the same intensity
- adjusting word order so technical explanations scan naturally

## Not Allowed Without Approval

These moves require explicit approval because they change editorial intent:

- rewriting the intro hook
- changing article scope
- adding sections from source code that were not discussed in the source post
- adding new resource links
- adding commercial messaging not present in the source
- changing the strength of comparisons with Flutter, native, or other stacks

## Translation Review Checklist

Before finalizing a translation, verify:

- the translated title matches the source title's scope and promise
- the description does not oversell beyond the source
- each section still does the same job as in the source
- no new claims were introduced
- no source claims were weakened or removed without reason
- chronology still matches the source
- all identifiers, ranges, and strings are grounded in source code or source article text
- code blocks are unchanged unless explicitly requested
- the conclusion has the same intent and energy as the source

## Drift Detection Checklist

A translation likely drifted too far if any of these happened:

- the first paragraph now argues something the source never argued
- the translation sounds more provocative than the source
- the translation adds advice, tools, or plugins the source did not mention
- the translation adds sections that feel like new content, not translated content
- the translation turns a practical article into a manifesto
- the translation changes what the article seems to be about

If any of these are true, pull the draft back toward the source.

## Recommended Workflow

1. Read source article fully.
2. Read [WRITING_STYLE_GUIDE.md](WRITING_STYLE_GUIDE.md).
3. Identify the article's promise, tone, and structure.
4. Translate section by section.
5. Compare the translation against the source for drift.
6. Verify names, code, links, chronology, and front matter.
7. Do one final pass for natural target-language flow.

## Short Rule Of Thumb

Translate the article the author wrote.
Do not quietly write a different article that happens to use the same code samples.