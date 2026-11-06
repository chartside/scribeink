# Clinical note templates

The starting set of note templates for ScribeInk's on-device clinical scribe. Each file is
one template in the format described in [`SCHEMA.md`](SCHEMA.md). The templates aren't
connected to the app yet.

## The set

| File | Note type |
|---|---|
| `soap_single.v1.yaml` | SOAP note, single issue |
| `soap_issues.v1.yaml` | GP visit, SOAP by issue |
| `internal_medicine_new.v1.yaml` | Internal medicine new patient, with patient summary |
| `cardiology_soap.v1.yaml` | Cardiology SOAP |
| `consult_letter_cardiology.v1.yaml` | Cardiology letter to the referring physician (stress test findings) |
| `psychiatric_consultation.v1.yaml` | Psychiatric consultation with mental status exam |
| `geriatric_assessment.v1.yaml` | Comprehensive geriatric assessment |
| `emergency_note.v1.yaml` | Emergency note (HPI, PE, impression and plan, reassessment) |

## Rules every template follows

These rules come from `SCHEMA.md`. Any new template, and any code that uses one, must keep them.

- **Only what was said.** A section holds only what the transcript, the clinician's notes or
  an earlier note says. If nothing was said for a section, it stays empty. The output never
  says that something "was not mentioned".
- **No defaults.** A section has no default text. A body system nobody examined out loud is
  left out. It is never written as "normal".
- **Conclusions are the clinician's.** Sections that hold a conclusion (assessment,
  impression, diagnosis, differential, plan) or an examination are `stated_only`. The model
  writes only what the clinician said. It never infers or suggests a diagnosis, a
  differential or a plan.
- **Patient identity only as said aloud.** A note template may have one `identity: true`
  section: the patient's name, age, gender and health number as they were said in the
  visit. Three templates have one: `emergency_note`, `internal_medicine_new` and
  `psychiatric_consultation`. A health number is kept only if it passes the BC PHN or
  Ontario health-number checksum. Otherwise the sentence is dropped, never corrected.
  Letters and other documents have no identity section. The clinician fills in identity
  there from the chart.
- **No numbers in guidance.** Guidance can describe a value "as it was said". It never sets
  a threshold or a dose.
- **No fixed boilerplate.** Fixed sentences (an opening line, consent lines, a medication
  counselling paragraph) are not part of any template. They belong in the clinician's own
  settings and are inserted only when the clinician chooses.

## Templates to build next

- **Clinical notes:** Telehealth consultation, H & P, H & P with issues list, Issues list,
  Patient explainer letter, GP letter with summary, Referral letter, Cardiac
  electrophysiology consultation, Cardiology follow-up, Echocardiography report, Holter
  summary, Ward round / clinical handover, Discharge planning meeting, Family meeting /
  case conference, Mental health care planning, SMART goals.
- **By specialty:** Depression follow-up, Gyne/PAP visit, Family medicine visit, Well child
  check, Psychosocial/ADHD assessment, Gynaecology consult, Gastroenterology consult,
  Psychotherapy progress note, Chronic pain, Prenatal consult, Internal medicine follow-up,
  Full ED physician note, Complete physical exam, Palliative consult, Patient visit summary
  letter, Multiple-issue visit, General paediatrics consult.
- **Forms:** Disability Tax Credit Certificate (T2201), CPP disability medical report, MoCA.
  These are form fills, not notes. The scribe only drafts their free-text boxes. The
  clinician ticks, dates and signs everything else.
- **Meetings (lower priority):** MDT, M&M, clinical governance, board minutes, team stand-up
  and similar.
