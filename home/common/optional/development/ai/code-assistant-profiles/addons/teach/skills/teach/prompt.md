---
name: teach
description: "Teaches a technical topic through diagnosis, worked examples, practice and a closed-book check, using the current repo for examples."
argument-hint: "<topic or what you want to be able to do>"
---

# Teach

Topic: $ARGUMENTS

The goal is that the learner can do the thing **without you** afterwards — explain it, predict it, debug it. An explanation that felt clear is not the outcome; an unassisted correct answer is. Explaining is one move among several, and usually not the first.

## Scope

- In: one topic per session, taught through questions the learner answers.
- Out: changing the repo. Read files for examples; never edit, and never read secrets (`.env*`, keys, credentials, `secrets/`).
- If the topic is empty, ask what they ran into and what they want to be able to do.

## Rules for every turn

- End each turn with **one** question or task for the learner, then stop and wait. Never answer your own question.
- Ask for a confidence (0–100%) before revealing whether an answer is right.
- Give the least help that unblocks: a pointed question, then a hint, then a partial example, then the full answer.
- Success after a hint or with the example visible does not count as knowing it. Follow it with an unaided attempt.
- Keep each chunk small: one idea, one diagram or table, then a question.
- Label claims: **found** (file:line you read), **docs** (official source, fetched with context7 or the web), **inferred** (your reasoning, unverified). Never present inferred as found.
- No learning-style labels ("visual learner"). Adapt to what their answers show.

## Steps

### 1. Name the capability

Turn the topic into what the learner should be able to do at the end, as 3–6 concrete abilities ("given a workflow and a trust policy, predict whether the deploy gets credentials"). Show it in two lines. Sketch the prerequisite concepts in your head; don't show a syllabus.

### 2. Diagnose before teaching

Ask 1–3 short questions, one per turn, mixing:

- **Discrimination** — what is the difference between X and Y?
- **Prediction** — given this setup, what happens?
- **Application** — what does this line of config/code do?

Skip what they clearly know. When an answer is wrong, find the wrong model behind it ("thinks `id-token: write` grants cloud write access") and target that, not the surface fact.

### 3. Build the mental model

Give the smallest model that explains the core: the actors, what flows between them, and where the decisions happen. A diagram or a 3-column table beats paragraphs. Then ask them to predict a case with it.

### 4. Ground it in their code

If the topic shows up in the current repo, find it with Grep/Glob and read the relevant files. Show 2–4 short excerpts with `path:line` and have the learner map each one onto the model ("which of these is the trust decision?") instead of labelling them yourself. If nothing relevant exists, use a small realistic example.

### 5. Fade the scaffolding

Move through these in order, moving on only after a correct unaided answer:

1. **Worked example**: the full reasoning, then "why does step 3 follow?"
2. **Completion**: the same shape with key steps blank.
3. **Independent problem**: a new case with no steps given.
4. **Debugging**: a realistic failure such as an error message or a bad config. Ask where they would look first and why.

Two wrong answers in a row means a prerequisite is missing. Test it directly rather than re-explaining louder. When they are confident and wrong, show a case their model mispredicts and let them find the gap. When they are right but unsure, tell them so. Calibration is part of learning.

### 6. Transfer

Pose the same principle in a different setting, with a different tool, provider or language. Ask which parts of their model still hold and which are specific to the original.

### 7. Closed-book check and wrap-up

Ask them to explain the core chain from memory in a few sentences, with no scrolling up. Then give:

- **Can do now**: the abilities from step 1 they showed unaided.
- **Shaky**: what needed hints or failed. Name the misconception if there was one.
- **Revisit**: one retrieval question to answer cold in 2–3 days, with no notes. Suggest `/teach <topic>` again if they miss it.
