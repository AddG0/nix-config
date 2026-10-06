---
name: write-for-people
description: "Drafts text other people read, like MR notes, tickets, chat and email, in a plain human voice. Use before writing anything posted outside this chat."
---

# Writing for people

## Scope

In: anything a colleague, reviewer or customer reads outside this conversation: MR and PR notes, MR descriptions, ticket descriptions and comments, bug reports, chat messages, emails.
Out: how you talk to the user in this chat (the always-on rules cover that), code comments (the comments rule), long-form docs (`write-concisely`). The `jira` skill owns ticket templates and the CLI; this skill sets the voice.

## Voice

Write like a competent colleague typing to another one. Lead with the point, use real names, numbers and paths, and stop when you're done. The reader is busy, skims, and judges the message by its first line.

Readers spot AI text mostly by its content, not single words: claims that fit any MR, praise with no object, a tidy recap of what they just read. Specifics fix that. A sentence that names the function, the number and the ticket reads as written by someone who looked.

Own every claim. Before posting, check each path, line number, function name, figure and quoted error against the source. One confident wrong detail costs more trust than any phrasing. Don't hedge with "AI-generated, may contain errors"; verify it or cut it. Whether to mention AI help is the user's call.

Write this way:
- Plain words: use, need, about, get, many, start, help. Not utilize, require, approximately, obtain, numerous, initiate, facilitate, leverage.
- Plain verbs: "is" and "has", not "serves as", "stands as", "features", "boasts".
- Active voice with a named actor: "the cache never cleared", not "cache clearing was not performed".
- Contractions and mixed sentence lengths. Split anything over about 25 words.
- Ordinary punctuation: periods, commas, parentheses, colons. No em or en dashes. Claude uses them more than human writers do and readers treat them as the giveaway. Write ranges as "10 to 20".
- Neutral tone. State the fact and let the reader decide whether it's good news.

**First sentence carries the point**: the outcome, decision, ask or blocker. If deleting the first sentence loses nothing, delete it.

**Prose by default.** A short paragraph beats the same thought chopped into bullets. Lists are for genuinely parallel items: steps, acceptance criteria, several separate findings. Headings only in something long enough to navigate (an MR description, a bug report), never in a chat message or review note.

**Low context.** Write so someone who missed the meeting can act. Say what's behind a link: "same N+1 as #4412 (orders list)", not "see #4412". Link code with a commit permalink, not a branch.

## Patterns to cut

Scan the draft for these. They're the ones that show up most in work messages; the fuller list, with how well each is evidenced, is in `${SKILL_DIR}/references/ai-tells.md`.
- Negative parallelism: "not just X, it's Y", "not X but Y", "X rather than Y". Say Y.
- Rule of three: three adjectives or a three-part list when the real count is one or two.
- An "-ing" tail claiming significance: "..., ensuring consistency across the codebase." Delete it or state the concrete effect.
- Warm-ups and wrap-ups: "I wanted to flag", "It's worth noting", "Overall,", "In summary", "Hope this helps", "Let me know if you have any questions".
- Sycophancy and fake enthusiasm: "Great catch!", "You're absolutely right", "Excellent work!", exclamation marks.
- Mannered phrasing: a metaphor where a literal phrase exists ("this earns its keep", "moves the needle"). Say what you mean.
- Formatting nobody types by hand in a comment: title-case headings, bold on every key term, bullets that open with a bold label and a colon.

Avoiding the list doesn't make writing good, and swapping each tell for a near-synonym makes new ones (every dash turned into a colon). Rewrite the sentence, not the token.

## By medium

### Review notes (MR/PR)

One finding per note, on the line it's about. Say what goes wrong and when, then what you want. The first few words should tell the author whether it blocks the merge.

Mark the weight. Without a label, authors treat every comment as mandatory. Follow whatever convention the MR thread already uses; otherwise:
- No prefix: a defect that blocks the merge. State it as a problem, not a question.
- `Nit:` minor, fine to ignore.
- `Non-blocking:` a suggestion you'd like but won't hold the MR for.
- `Question:` you don't know yet whether it's a problem.
- `FYI:` context, no action expected in this MR.

If the team uses Conventional Comments, write `issue (blocking):`, `suggestion (non-blocking):`, `nitpick:`, `question:` instead.

Ask when you're genuinely unsure; state it when you're not. A real bug phrased as "Could we maybe...?" reads as optional and gets skipped. Courtesy comes from talking about the code rather than the author and from giving the reason, not from turning a requirement into a question.
- AI: "Consider improving error handling here to ensure robustness."
- Human (blocking): "Rejected `getUser` calls become `name: null` with nothing logged, so a Clerk outage just shows 'Unknown member'. This needs a `console.error` and `Sentry.captureException` per rejection before it merges."
- Human (question): "Question: can `items` be empty here? If so, `items[0].price` throws on the free-shipping path."
- Human (nit): "Nit: `res2` could be `retryResponse`."

Ask for the fix in this MR by default. If it's genuinely out of scope, say so, mark it `FYI:` or `Non-blocking:`, and link the follow-up ticket if there is one.

Praise only what's specific and true: "The retry test pinning the exact backoff schedule is a nice touch." Never a generic "Great work!" opener.

Replying to a review: say what you changed and where. "Fixed in a1b2c3d, moved the null check above the loop." Not "Great catch, thanks so much! I've gone ahead and addressed this."

### MR descriptions

First line: what the change does, as a standalone imperative sentence ("Cache carrier rates for 5 minutes per origin"). Then why, any option a reviewer would ask about and why you didn't take it, known gaps, and how to verify. Link the ticket instead of restating it. "Fix bug" is not a description: which bug, fixed how?

### Tickets and bug reports

Bug title: name the problem, not the fix, in about ten words ("Checkout returns 500 when the cart has a free item", not "Fix checkout"). Body: numbered steps to reproduce, expected result, actual result with the exact error, and whether it happens every time. Keep what you saw apart from what you suspect: "Saw X. I think it's Y because Z."

Stories and tasks: the problem in a sentence or two, the outcome wanted, and acceptance criteria as pass/fail outcomes someone can check, not tasks.

### Ticket comments

What changed and what you're seeing, with specifics. A few sentences, no headers.
- AI: "I've delved into the root cause and made good progress; a fix has been implemented and we are monitoring closely."
- Human: "Root cause was a stale cache key. Deployed the fix at 14:20, error rate is down from 4% to 0.1% so far."

### Blockers

What you need, from whom, by when, and what you've tried.
- Human: "Blocked: I need read access to the staging DB to reproduce this. Pinged Sarah yesterday, no reply yet. Without it I can't verify the fix before Thursday's release."

### Chat

The question or answer goes in the first message. A bare "hi" or "got a sec?" makes the reader wait for a question they could already be answering; a greeting on the same line is fine. One message per topic, not a burst of fragments; extra detail goes in the thread. When someone asks for something, reply with a time or a result, not "will do".
- AI: "Hi! Hope you're doing well. I wanted to reach out regarding the deployment pipeline. Do you have a moment?"
- Human: "Hey, is the prod deploy still frozen? I've got a one-line fix for the rates timeout (ENG26-1940) ready to go."

### Email

Bottom line first: the decision, request or deadline in the opening sentence, background after. The subject says what you want ("Decision needed: retire the v1 rates API on 1 Nov"). Keep it to one screen. No "I hope this email finds you well", and no sign-off beyond your name.

## Before posting

Reread once as the recipient. From the first line alone, do they know what happened or what you need? Is every name, number and path checked? Would a teammate type this sentence? Cut the warm-up, the wrap-up, and any line that carries no information.
