# AI-writing tells: what's evidenced and what isn't

Use this as a revision checklist, not a generator. A single hit proves nothing; humans write most of these too. Several together, in a short work message where nobody would bother with the flourish, is what reads as AI. Fixing the tokens without fixing the sentence just produces new tells.

Strength: **strong** = several independent studies or a large corpus comparison; **model-specific** = true for some models or eras, not others; **weak** = folklore, or evidence points the other way.

## Language

| Tell | Strength | Fix |
| --- | --- | --- |
| Clusters of "AI vocabulary": crucial, pivotal, key (adj.), enhance, highlight/underscore/showcase (verbs), foster, intricate, landscape (abstract), testament, tapestry, valuable, vibrant, align with | strong as a cluster, weak for one word | Use the plain word or cut it. The list shifts by model and year. |
| "-ing" tail asserting significance: "..., highlighting/ensuring/reflecting/contributing to ..." | strong | Delete it, or state the concrete effect in its own sentence. |
| Copula avoidance: "serves as", "stands as", "marks", "represents", "features", "boasts" instead of is/has | strong | Use "is" or "has". |
| Negative parallelism: "not only X but Y", "it's not X, it's Y", "no X, no Y, just Z", "Y rather than X" | strong | State Y. Keep a contrast only when someone actually believes X. |
| Rule of three: triple adjectives, three-part phrase lists | strong | Use the real count. |
| Latinate diction: require, approximately, obtain, numerous, utilize, facilitate, initiate | strong (2026 corpus study) | need, about, get, many, use, help, start. |
| Promotional or upbeat tone, significance inflation ("a pivotal step", "game-changer") | strong | State the fact; let the reader judge. |
| Vague attribution: "experts say", "industry reports", "it's widely recognized" | strong | Name the source or drop the claim. |
| Mannered metaphor: "earns its keep", "a dial worth turning", "load-bearing" | model-specific (Anthropic flags it for its own recent models) | Say the literal thing. |
| Sentence-initial "Additionally", "Furthermore", "Moreover" | weak on its own | Usually cut; "Also" or nothing. |
| "delve" | weak now; faded sharply in 2025 | Not worth hunting. |
| Wordy phrases like "in order to", "the fact that" | not an AI tell (more common in human text) | Cut for concision, not disguise. |
| Synonyms of listed words | not a tell | Overuse of a word says nothing about its synonyms. |

## Structure and formatting

| Tell | Strength | Fix |
| --- | --- | --- |
| Summary closer: "Overall,", "In summary", "In conclusion", restating the point at the end | strong (more so in older models) | Stop after the last new fact. |
| Headings in a comment or chat message; title-case headings | strong | No headings in short text; sentence case where they're warranted. |
| Bold on every key term | strong | Bold nothing, or one thing the reader must not miss. |
| Bullets opening with a bold label and a colon ("**Performance**: ...") | strong | Prose, or plain bullets. |
| Emoji as bullet markers or section icons | strong | Drop them. |
| Em dashes | model-specific: a 2026 comparison found only Claude still uses more than professional writers; ChatGPT now uses fewer. Weak on its own. | Comma, period, colon or parentheses. Since this is Claude writing, avoid them. |
| Sparse punctuation: long "and"-chained sentences, few commas, hardly any parentheses | model-specific (2026 corpus study) | Shorter sentences; use parentheses and commas where a person would. |
| Curly quotes and apostrophes | model-specific (ChatGPT, DeepSeek; Claude usually doesn't) | Straight quotes, especially in code-adjacent text. |

## Communication with the reader

| Tell | Strength | Fix |
| --- | --- | --- |
| Chatbot leftovers: "Certainly!", "Here is a...", "I hope this helps", "Let me know if...", "Would you like..." | strong | Delete. |
| Customer-service register: "I have carefully reviewed", "apologies for any inconvenience", "please point out any issues and I will resolve them" | strong (Wikipedia, comment-specific) | Say what you did and what's next. |
| Sycophancy: "Great question", "You're absolutely right", "Excellent catch!" | strong | Answer the point. Agree by acting on it. |
| Disclaimers that hedge accountability ("this may contain errors") | strong as a smell | Verify, then post without it. |

## What is not a reliable sign

Perfect grammar, formal or "bland" prose in general, mixed casual and technical register, and transition words in isolation. Wikipedia lists these as ineffective indicators. Human text is more likely than AI text to contain simple is/has sentences, plain verbs (wrote, used, tried), definite claims ("the only", "the first"), and qualifiers (very, perhaps, tends to), so these are safe to keep.

Detection by eye is unreliable for most readers (near chance in several studies), but people who use LLMs heavily for writing are very accurate, and they key on vocabulary plus formality, originality and clarity. Generic content is the hardest thing to hide; specific content is the fix.

## Sources

- Wikipedia, "Signs of AI writing": https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
- Russell, Karpinska, Iyyer, ACL 2025, expert annotators: https://aclanthology.org/2025.acl-long.267/
- Reinhart et al., PNAS 2025, grammatical style of LLMs: https://www.pnas.org/doi/10.1073/pnas.2422455122
- Kobak et al., Science Advances 2025, excess vocabulary: https://www.science.org/doi/10.1126/sciadv.adt3813
- The Economist, "How to spot AI writing", 30 July 2026 (via https://daringfireball.net/linked/2026/08/11/economist-ai-writing)
- Anthropic, mannered prose: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1
