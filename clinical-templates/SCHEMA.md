# Note template format

A note template tells the scribe which sections a draft has and what each section holds. It
is a YAML file named `<template>.v<version>.yaml`. The template is the only source of
section names: the model cannot add a section, and the draft is checked so that a section
it adds is refused.

This format is a safety boundary. A draft is a document a clinician signs. The format
gives the model no field it fills from its own judgement.

## Shape

```yaml
template: soap_single     # the key; matches the file name
version: 1                # an integer; matches the file name
title: SOAP note          # what the clinician sees in the template picker
sections:
  - key: subjective       # lower case, digits and underscores
    title: Subjective     # the heading printed in the draft
    stated_only: false
    format: bullets       # optional: bullets | numbered | narrative (the default)
    guidance: >
      What the patient said about why they came, in their words where possible.
    style_example: |      # optional; form only; never on a stated_only section
      - Worsening shortness of breath over the past few weeks
      - No fever, chest pain or coughing up blood
  - key: objective
    title: Objective
    stated_only: true
    format: bullets
    guidance: >
      Only the examination findings the clinician said aloud ...
    exam:                 # optional; only on a stated_only section
      - {key: vitals, title: Vital signs}
      - {key: cvs, title: Cardiovascular}
```

### Top-level keys

| Key | Required | Meaning |
|---|---|---|
| `template` | yes | The template's key. Lower case, digits and underscores. |
| `version` | yes | An integer. A change to a template in use is a new file with the next version. |
| `title` | yes | The name shown to the clinician. |
| `status` | no | `draft` on a template the model made, or one being imported, that the clinician has not saved yet. A shipped file never has it; saving drops it. |
| `document` | no | What the template makes: `note` (the default), `correspondence`, `patient_instructions`, `work_school` or `certificate`. See "Document templates". |
| `purpose` | with a `document` other than `note` | One sentence for the clinician: what the document is for and who reads it. Shown in the preview, never sent to a model. |
| `sections` | yes | The fixed sections, in the order they print. |

### Section keys

| Key | Required | Meaning |
|---|---|---|
| `key` | yes | Unique in the template. Lower case, digits and underscores. |
| `title` | yes | The heading. |
| `stated_only` | yes | `true` or `false`. |
| `guidance` | yes | One or two sentences for the prompt: what the section holds. |
| `format` | no | `bullets`, `numbered` or `narrative` (the default). How the sentences are laid out: one bullet or one number per sentence, or one paragraph. It changes no sentence. |
| `style_example` | no | A short passage that shows how the section reads: layout, sentence shape, abbreviations, tense. Read by pass 2 only (see "Two passes"). |
| `exam` | no | On a `stated_only` section only: the examination headings, each `{key, title}`. Pass 1 is asked for one list per heading; a heading nobody examined aloud has no sentence and is not printed. |
| `identity` | no | `true` or `false` (the default). `true` makes the section the note's opener: the patient's name, age, gender and health number as said aloud. See "The identity section". |

A section has no other key.

## Rules

- **Every sentence is grounded or marked.** Each sentence of the draft is aligned to the
  transcript spans it came from. A sentence with no span is shown to the clinician as
  ungrounded. This applies to every section.
- **`stated_only: true` means only what the clinician said aloud.** The guidance of such a
  section says so and ends with the instruction to leave the section empty if nothing was
  said. There is no speaker attribution, so `stated_only` is a prompt rule plus grounding,
  not a structural check; test it against synthetic encounters.
- **A section has no `default`, no `example` and no `options`.** The model is never given a
  menu of diagnoses, findings or plans to choose from, and never an example answer to copy.
- **`style_example` is form only.** It shows how a section reads, not what it says, so:
  - it is refused on a `stated_only` section, where any example is text nobody said;
  - it holds no digit (a number in it could reach the note), none of the forbidden words
    below and no count, and is at most 600 characters;
  - it reaches pass 2 only, which restyles pass 1's sentences and adds nothing, and is
    told that none of the example's words belong in the note. A sentence that copies one
    anyway is not in the transcript and comes back ungrounded.
- **A heading that names a conclusion is `stated_only`.** A section whose key or title says
  assessment, impression, diagnosis, plan or recommendations, or is a problem list, and is
  not `stated_only`, is refused: the model never writes one of its own. "Presenting
  problem" is history and is not caught. There is no "clinical impression" field.
- **An examination is what was said aloud.** An `exam` section is `stated_only`. A system
  nobody examined aloud is left out, never written as normal. A sentence that says
  "normal", "unremarkable", "clear" or similar must cite a transcript segment that says it.
- **Guidance describes, it does not prompt judgement.** `guidance` contains none of these
  words, in any case: suggest, consider, recommend, likely, rule out, differential, score,
  severity, urgent. A word that contains one of them (for example "unlikely") is refused
  too. A `title` is a heading, not an instruction, so it is checked for the words
  themselves ("Recommendations" over what a specialist said aloud stays; "Likely
  diagnosis" does not). Assessment asks for "the diagnosis the clinician stated, and any
  alternatives they said they were weighing". A style example is checked for the same words.
- **Guidance never asks for a count.** "At least", "at most", "no more than", "no fewer
  than" and "a minimum of" are refused in guidance and in a style example: "at least 2
  actions" invites the model to invent the second.
- **Numbers are transcribed, never read.** Guidance may ask for a value as it was spoken. It
  never asks the model to compare, classify or flag one.
- **Standing text is not part of a template.** Fixed sentences a clinician keeps for a
  template (an opening line, a consent line, a medication counselling paragraph) are the
  clinician's own settings, inserted only when they choose. A template body holds none of
  them, and no section asks the model to write them.

## The identity section

A note template may open with the patient's name, age, gender and health number as said
aloud.

- The section has `identity: true`. A template has at most one.
- It is never `stated_only`, and it has no `style_example` and no `exam`.
- It is drafted and grounded like any other section.
- A sentence of it that holds a ten-digit number, in digits or said as words, is kept only
  when the number passes the BC PHN or the Ontario health-number checksum. A number that
  fails is treated as absent: the sentence is dropped, never corrected.

## Document templates

A template makes a visit note unless it says otherwise. `document` names what else it
makes. It is a label and a set of refusals: it changes no prompt, and a section of a
document is drafted and grounded like a section of a note.

| `document` | What it is | Examples here |
|---|---|---|
| `note` (default) | The visit's own record. | every template except the one below |
| `correspondence` | A letter to another clinician about the patient: a referral, a consult reply, a letter back to the referrer. | `consult_letter_cardiology` |
| `patient_instructions` | Written for the patient: what was said, what to do, what happens next. | none yet |
| `work_school` | A letter for an employer, a school or a program. | none yet |
| `certificate` | A certificate the clinician writes and signs on their own letterhead. | none yet |

The rules below hold for every `document` other than `note`:

- **Some parts are the clinician's alone.** The recipient, the patient's identity, the
  date, the signature and the signatory, and on a certificate the certification itself,
  are never drafted. They are not sections: the template has no field for them, none of
  them is sent to a model, and each is shown as an empty labelled line for the clinician
  to complete. So a section whose key or title names one is refused (a signature,
  signatory, recipient or addressee, "Dear" or "To whom", a heading that is just "Date" or
  "To", the patient's name, identity, details or demographics, a date of birth, a health
  number or PHN, or any form of "certify" or "attest"). An `identity: true` section is
  refused too.
- **No digit anywhere.** A digit in the title, `purpose`, a section's title, guidance or
  style example is refused. A number in it could reach a letter a third party reads.
- **`purpose` is required**, passes the guidance word checks and is at most 300 characters.
- **A `stated_only` section says how it stays empty.** Its guidance holds the words "leave
  this section empty" (any case), so that instruction is checked, not trusted.

On top of those, a `work_school` or a `certificate` template:

- **Holds no judgement the model writes.** A fitness, capacity, restriction, duration or
  return-to-work judgement is the clinician's alone: every section of a `certificate` is
  `stated_only`, and a `work_school` section that names one is refused unless it is
  `stated_only`.
- **Has no `style_example`.**
- **Keeps no ungrounded sentence.** A sentence with no grounding is dropped, not shown, and
  a section left with none is empty. A fact nobody said stays missing.

## Two passes

A draft is made in two passes, both by a model running on the device.

1. **Extract.** Every section's guidance (one key per exam heading) and the numbered
   transcript. The model returns, per key, only what was discussed, each sentence with the
   segment numbers it restates, and an empty list for a key with nothing.
2. **Restyle.** Only a section that is not `stated_only`, has something from pass 1, and
   has a `style_example` or the clinician's note settings. The model sees the example (if
   any) and pass 1's sentences of that section, numbered, and never the transcript. It
   rewrites them in the example's form and cites the pass-1 sentences each one restates. If
   it leaves one out, the section keeps pass 1's sentences.

Grounding runs on what the draft returns, against the segments pass 1 cited.

## Saved templates

A template the clinician saves is the same format and passes the same checks. It is stored
on the device, encrypted. Saving makes a new version; nothing is replaced silently. A
template the model made, or one imported from another clinician's file, comes back with
`status: draft` and reaches a draft only once the clinician saves it. An imported template
is refused when any of its text holds a digit.

## What a template cannot express

- A field the model fills from its own judgement: an impression, a diagnosis, a severity or
  a next step that nobody said.
- A choice list, a default value or an example answer.
- A count of points the model has to reach.
- A rating, a scale, a grade or a score.
- A condition on a value ("if the pressure is high").
- A section that appears or hides depending on what was said.
- In a document other than a `note`: the recipient, the patient's identity, the date, a
  signature, a signatory or a certification.
