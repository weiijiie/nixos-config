# Writing

Applies to prose you write: docs, PR descriptions, commit messages, comments,
and chat. Not to material you quote or transcribe verbatim.

- No em-dashes. Use a plain hyphen, a semicolon, parentheses, or restructure
  the sentence.
- Short sentences with one idea each; define every term of art at first use
  or drop it; state the point before its qualifications; concrete numbers
  over abstract phrasing.
- A document is about its subject, not about itself. Don't name the style or
  format convention you wrote in, and don't reference or correct a version you
  have already replaced; a revision reads as the current state of knowledge.
  Keep to the subject the title names, and bring in a prior or related event
  only as compact context where it carries the explanation, never as a second
  timeline.
- In a runbook or an operational step, give the action and the decision it
  drives. Cut any clause that does not change what the operator does next;
  keep a mechanism detail only where it changes the command they run.
- Explaining a mechanism: introduce one small example and follow that same
  example all the way through. Give the common case first and the edge cases
  and failure modes after, not the other way around.
- When rewording to avoid overlapping a source or template, natural plain
  phrasing wins. If no natural alternative exists, keep the original wording
  and note the overlap rather than reaching for a strained synonym.
- In committed markdown, write callouts as plain blockquotes
  (`> 🚨 **Lead-in.** text`) rather than GitHub `[!WARNING]` / `[!NOTE]`
  alert syntax. Markdown formatters fold the marker into the next line, and
  it then renders literally.
