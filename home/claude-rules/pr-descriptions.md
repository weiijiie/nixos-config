# PR descriptions

Structure, in this order. It satisfies the analytics repo's required
sections (Why, What, Test plan, Deployment plan) under plainer names.

    Linear: <issue url>

    ## Problem
    What is wrong or missing today, for whom, and why now.

    ## Solution
    The idea or principle, not the mechanics. What stays unchanged for
    existing consumers.

    ## Changes
    A few one-line bullets: a table of contents for the diff, not a
    walkthrough. The diff does the rest.

    ## Testing
    What ran and passed; what could not run and why; what to verify after
    deploy. If there is no new test, say so and why.

    ## Rollout
    Services and mechanism, named not guessed (ask if unknown); ordering;
    the post-deploy check; rollback in one line.

Style:

- Lean towards brevity. Short sections, no walls of text.
- Capture the high-level details that matter to the PR's main goal, even
  if the ticket or the diff also states them. Leave out minor details the
  code already covers (a fail-fast check on a metadata lookup, a helper's
  signature).
- Design justifications, alternatives considered, and investigation history
  belong in the ticket or the review thread, not the description.
- Testing and rollout are operational detail; keep them brief.
- Title: `[TICKET-NN] imperative summary`.
