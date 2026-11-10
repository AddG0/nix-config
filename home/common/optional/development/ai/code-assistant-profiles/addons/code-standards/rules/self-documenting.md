Code documents itself: open any file cold and you can say in one sentence what it is for and how it fits, without the chat, the commit or the author. Names and structure carry what they can; comments carry only what they cannot (see the comments rule); choosing the words is the domain-language-steward skill's job.

A file fails that test when:

- **It holds more than one concern.** One concern per file or package, named for it: `rates.ts`, not `utils.ts`. A concept's own results, events and errors can share its file; another concept can't hide there (`Order.kt` holding a retry policy fails). Go splits a package's files as they grow; `main.go`, `index.ts`, `default.nix` and `mod.rs` keep their names and stay thin.
- **Code sits where it was convenient.** It goes beside the code it changes with, not where a variable it needs was in scope. Edits that keep crossing a module boundary mean the boundary is wrong. This binds new code; moving old code is its own step.
- **The entry point isn't a story.** A top-level function is a short list of steps named by intent (`loadConfig`, `quoteRates`), each step's detail one call down. Extract a step only when it reads without its caller.
- **It groups by kind, not concept.** Layers inside one concept are fine. Settings sit under what they configure (`shipping.cutoffTime`). Tests follow the toolchain's layout, and their path names what they prove.
- **A bool or a sentinel carries the meaning.** A boolean that picks behaviour becomes an operation per behaviour or an enum; a `null` that means "saved" or a string that means "why not" becomes a type. Plain-data booleans like `isResidential`, and a nullable that means absent, are fine.
- **The contract is assembled.** Declare it in one place, a schema or typed options, not hand-checked maps.
- **A name means two things, or dead code looks live.** One name per concept in a context; delete what nothing calls.

Decide the shape before writing: list each file the change creates or reshapes with its one-sentence purpose and its names, and restructure the plan when a file has no sentence. In Claude Code a Stop hook checks what a script can on changed code; the self-documenting-reviewer agent gives a judgment read at hand-off.
