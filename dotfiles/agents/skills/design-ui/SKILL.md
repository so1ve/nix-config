---
name: design-ui
description: Apply the user's UI design standards when designing, implementing, or reviewing web or app interfaces, including layout, styling, components, and microcopy.
---

# UI Design

- Follow the user's brief and the product's existing design system. Choose layout,
  typography, color, and density for the subject, audience, and task. Reuse familiar
  components and interaction conventions.
- Keep the project's frontend, styling, component, and animation tools. Do not add
  a second system just to apply this skill. When implementing a supplied design,
  follow its visual decisions and explain any unavoidable differences.
- Reuse existing tokens for color, typography, spacing, radii, and motion. When a
  new interface has no design system, define a small shared set of values. Add
  tokens for reusable decisions; keep isolated adjustments local.
- Avoid unnecessary supporting text, descriptive copy, and redundant UI microcopy.
  Avoid unnecessary secondary labels and descriptions. Let the layout do the
  explaining. Remove subtitles that repeat headings, captions that narrate obvious
  controls, and generic introductions above working interfaces.
- Add help only where users need it to decide or act. First improve the control,
  label, or grouping. Keep necessary guidance close to the relevant action. Retain
  essential labels, units, constraints, consequences, and recovery instructions;
  do not hide them in tooltips or remove them for visual minimalism.
- Use the user's vocabulary and specific action labels, such as "Save changes" or
  "Download PDF". Keep names consistent throughout a flow. Remove promotional
  filler, vague promises, implementation jargon, and self-praise from product UI.
- Start with the actual task and content. Use lists, tables, forms, or direct
  manipulation when they fit. Do not automatically turn tools into landing pages
  with oversized heroes, feature grids, summary tiles, or repeated calls to action.
- Group related content with alignment, spacing, and headings. Add cards, borders,
  and panels when they express a meaningful boundary. Avoid wrapping every section
  in an identical rounded card or nesting cards just to create structure.
- Use decoration deliberately. Gradients, glass effects, glows, shadows, large
  radii, and decorative icons need a purpose in the chosen design. Do not apply a
  fashionable palette or component preset to every project, or change an existing
  visual identity just to make it look less AI-generated.
- Avoid decorative labels above every heading, excessive all-caps or letter
  spacing, arbitrary monospace metadata, and randomly emphasized headline words.
  Use numbered markers only for content that actually has an order. Keep type
  styles consistent and body text readable.
- Establish a clear visual hierarchy and make the main action easy to find.
  Distinguish secondary and destructive actions. Use whitespace to show groups
  and reading order; avoid oversized headings and padding that push useful content
  or routine actions out of view.
- Keep controls recognizable. Use native semantics, persistent form labels,
  accessible names, visible keyboard focus, and adequate contrast and hit areas.
  Use text for unfamiliar icons. Do not rely on placeholders, hover, or color alone
  to convey essential meaning or expose an action.
- Make hover, pressed, selected, and focus-visible states clear where applicable.
  Keep state changes from shifting nearby content. Reserve space for loading
  indicators, icon changes, and labels that become heavier when selected.
- Use motion to clarify a change or support the requested visual direction. Avoid
  animating every section and card, delaying access to content, or taking over
  scrolling. Reuse existing timing and easing tokens. Animate explicit properties
  and let repeated input interrupt or reverse a transition. Respect reduced-motion
  preferences.
- Make visible controls work and show the actual result of an action. Do not
  substitute a toast for the requested behavior, report success before an operation
  succeeds, or present invented metrics, testimonials, or integrations as real.
  Clearly identify demo data when a prototype needs it.
- Handle loading, empty, populated, error, and disabled states for the supported
  flow. Keep errors actionable and close to their cause, preserve user input on
  failure, and provide recovery. Empty states should explain the next useful step
  without adding promotional copy or dummy content.
- Check the rendered interface and its main interactions before finishing. Use
  realistic content, including long labels and dense data. Verify narrow layouts,
  zoom, and keyboard use; fix clipping, accidental overflow, hidden actions, and
  overlays that obscure content. A polished static screenshot is insufficient.
- In UI reviews, locate each finding (`file:line` when available), describe what
  a user observes, and suggest a concrete fix. Support findings with code or
  rendered behavior. Separate defects from optional refinements; a review may have
  no findings.

References:

- [GOV.UK: Writing for user interfaces](https://www.gov.uk/service-manual/design/writing-for-user-interfaces)
- [DWP: Hint text](https://design-system.dwp.gov.uk/guidance/hint-text)
- [NN/G: Aesthetic and minimalist design](https://www.nngroup.com/articles/aesthetic-minimalist-design/)
- [Anthropic: Frontend design](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md)
- [Vercel: Web interface guidelines](https://vercel.com/design/guidelines)
- [mzwing: Design UI](https://github.com/mzwing/nix-config/blob/2e2a7cbb987a10702d0ce993950532dc56d0e084/data/skills/local/design-ui/SKILL.md)
