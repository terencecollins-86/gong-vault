---
title: "AI4Dev Use Cases - R&D"
source: "https://gongio.atlassian.net/wiki/spaces/EN/pages/4246831287/AI4Dev+Use+Cases#Use-Case-Template"
author:
published:
created: 2026-06-17
description:
tags:
  - "clippings"
---
## AI4Dev Use Cases

This page showcases real examples of how engineers at Gong are using AI tools like Claude and Copilot to solve development challenges, automate tasks, and boost productivity.

Each use case follows a consistent template, from the problem and approach to results, surprises, and lessons learned. Whether you're exploring AI for code review, migrations, or testing, use this page to get inspired, learn what works (and what doesn't), and build your own effective AI workflows.

**Have a use case to add? Use the template below to contribute!**

## Use Case Template

***Use Case Title:** \[Concise Title of the Use Case\]*  
***AI Tool Used:** Claude Code*  
***Project Context:** \[Brief description of the broader project or problem domain\]*  
***Primary Challenge:** \[The specific difficulty or bottleneck that prompted use of the AI tool\]*

***AI Prompt / Approach***  
***Prompt or Task Given to Claude:***  
*\[Exact or paraphrased version of the prompt or task you gave to Claude Code\]*

***Approach Taken:***

- *\[Step-by-step or high-level summary of how the tool was used\]*
- *\[Any relevant preparation or framing required before usage\]*

***Results***

- *\[Summary of what the tool delivered\]*
- *\[Highlight what worked well and what surprised you\]*
- *\[Quantitative or qualitative benefits, if applicable\]*

***What Went Wrong***

- *\[Issues with tool interpretation, context loss, or inaccuracies\]*
- *\[Any missteps during implementation or unexpected consequences\]*

***What We Learned***

- *\[Lessons learned about the tool's capabilities or limits\]*
- *\[Best practices or precautions for using Claude effectively in similar scenarios\]*

---

## Use Case 1: Researching Legacy Code

**AI Tool Used:** Claude Code @Gal Morad  
**Project Context:** Debugging a bug in a legacy codebase  
**Primary Challenge:** Understanding complex, poorly documented legacy code

**Prompt or Task Given to Claude:**  
"Add comments to explain this method" (method copied from JetBrains reference context menu)

**Approach Taken:**

- Provided Claude with isolated code snippets
- Asked for line-by-line comments and context-aware reasoning

**Results**

- Claude added clear, helpful comments
- Explained reasoning in relation to other classes in the codebase

**What Went Wrong**

- No major issues

**What We Learned**

- Claude is effective for understanding complex code
- Using IDE context tools improves the prompt quality

---

## Use Case 2: Streamlining PR Fixes Using Claude Code Plan Mode with GongReviewer

**AI Tool Used:** Claude Code @Tal Fishler

**Project Context:**

We've begun rolling out **GongReviewer**, an internal AI bot that performs automated code reviews and leaves feedback as PR comments. To help developers resolve this feedback faster and more efficiently, we explored integrating **Claude Code** to automatically plan and apply fixes based on the GongReviewer comments.

**Primary Challenge:**

Developers should spend less time interpreting GongReviewer's comments and manually implementing fixes, and implement faster, structured, and AI-supported way to go from feedback to resolved code.

**AI Prompt / Approach**

**Prompt or Task Given to Claude:**

- Use `/pr-comments <PR link>` to fetch GongReviewer feedback from the PR.
- Activate **plan mode** (Shift+Tab).
- Prompt Claude: *"Create a plan for fixing the issues described in the PR comments."*

**Approach Taken:**

1. **Trigger PR Review:** Developer comments `/review` in the PR to get feedback from GongReviewer.
2. **Fetch Feedback:** Use `/pr-comments <PR link>` to retrieve and summarize PR comments.
3. **Activate Plan Mode:** Press **Shift+Tab** to switch Claude Code into plan mode.
4. **Review Plan:** Go through Claude's proposed fix plan, adjusting it as needed.
5. **Confirm Execution:** Approve the plan. Claude enters **auto-accept mode** and applies the changes.
6. **Code Review:** Press **Shift+Tab** again to switch to review mode and inspect Claude's changes before merging.

**Preparation:** No special setup was needed beyond having GongReviewer enabled and Claude Code available.

**Results:**

- Claude generated **organized and actionable fix plans** aligned with GongReviewer comments.
- Enabled developers to move from feedback to fix in **a few focused steps**, reducing context-switching.
- The **review-before-apply approach** gave developers control while leveraging AI speed.
- Developers reported smoother workflows and **time savings** when dealing with small to mid-sized PRs.

**What Went Wrong:**

- Occasionally, Claude misinterpreted vague or unclear feedback, leading to irrelevant or over-scoped fixes.
- Some plans included unnecessary steps, which required manual clean-up.
- If the PR comments weren't well structured (e.g., too broad or ambiguous), Claude's plan quality dropped.

**What We Learned:**

- Claude Code's **plan + execute** model is a powerful companion to GongReviewer, especially when feedback is clear and scoped.
- Always **review and refine the plan** before confirming – a few manual tweaks improve quality significantly.
- Using Claude in **review mode** after auto-accept helps catch potential overcorrections or edge cases.
- Works best for **granular feedback loops** and not as well for major refactors or abstract guidance.

---

## Use Case 3: Component Migration Guide Creation

**AI Tool Used:** Claude Code @Roi Giladi  
**Project Context:** Upgrading legacy UI component (GongBtn) to a new design system (Pitch Component)  
**Primary Challenge:** Designing a safe and thorough migration path

**Prompt or Task Given to Claude:**  
"Analyze GongBtn and new Pitch component; create a migration guide and do small-scale migration"

**Approach Taken:**

- Used Claude to find all usages of GongBtn
- Compared APIs of old and new components
- Drafted a migration strategy and tried it on select examples

**Results**

- Delivered a comprehensive migration guide
- Included key differences, prop mappings, examples, and pitfalls
- Migration mostly successful except for edge cases

**What Went Wrong**

- Some incorrect transformations due to missing context
- A few inaccurate parts in the generated guide
- Missed some use cases in coverage

**What We Learned**

- Claude is highly useful for drafting structured documentation
- AI-generated guides must be manually reviewed for correctness and completeness
- Significant time saved, but careful supervision is required

---

## Use Case 4: Scalable Migration of Legacy React Components Using Claude and Codemods

**AI Tool Used:** Claude Code @Gal Morad  
**Project Context:** Migrating legacy components from the old `gong-web-ui` design system to the new `Pitch` system in `gong-design-system`  
**Primary Challenge:** Manual migration was time-consuming, error-prone, and difficult to scale across hundreds of component instances

**Prompt or Task Given to Claude:**  
Initial prompt:

I need help migrating from the legacy '{COMPONENT\_NAME}' component to our new Pitch design system equivalent.

Steps requested in initial prompt:

1. Compare both implementations and create a `MIGRATION_GUIDE.md`
2. Find all usages in `gong-web-ui` and upgrade them one by one according to the guide

**Approach Taken:**

- Used Claude to compare old and new component APIs and write a migration guide
- Attempted manual migration of component instances based on that guide (per Claude's help)
- Encountered scaling problems: hallucinations, inconsistency with the guide, and inefficiency across files
- Pivoted to asking Claude to generate a **codemod script** that automates the transformation
- Collaboratively iterated with Claude to produce:
	- A `run-codemod` utility script
		- Component-specific codemod scripts (e.g. `gong-btn`)
		- Usage inventory files and corresponding README instructions

**Results**

- Successful generation of a working codemod that upgraded 200+ instances in seconds
- Codemod followed migration rules accurately and predictably
- Prompt evolved into a reusable format that now works across other component migrations
- Saved days of manual work
- Final prompt includes everything needed for a reproducible and maintainable migration workflow

**What Went Wrong**

- Initial manual migration process failed due to:
	- Hallucinated code
		- Inconsistent adherence to the migration guide
		- Performance limitations (large token and time requirements)
- Required several manual corrections and re-prompts before codemod solution was stable

**What We Learned**

- Claude is excellent for generating migration scaffolding but struggles with large-scale, file-by-file manual migration
- Codemods provide a far more reliable and scalable solution when paired with AI-generated logic
- A well-structured, multi-part prompt yields reusable tools and outputs
- AI support is most powerful when complemented by automation and human QA
- Clear, repeatable prompts make the strategy transferable to other components

---

## Use Case 5: Adding tests to existing code

**AI Tool Used:** Claude Code / Copilot (Edit mode) @Nimrod Argov  
**Project Context:** Adding missing tests to an existing Controller after having added an edge case check  
**Primary Challenge:** Adding tests to existing code requires making sure you catch all of the use-cases that can arise, and can also be repetitive work that is well suited for AI.

**AI Prompt / Approach**  
**Prompt or Task Given to Claude/Copilot:**  
I have added an additional catch clause to one of the controller functions in this class. The controller has a test class \[name\] but only contains a couple of tests. Add the missing tests to cover all of the methods as well as the error handling and edge cases.  
Pay attention to already written tests for test form, and use the already prepared mocks.

**Approach Taken**

- At first, I used Claude to generate the tests. It created all the expected tests (as well as a few ones I didn't think of)
- The tests didn't even compile, and I had to point the issues out to Claude, which fixed the issues.
- A few of the tests were red because of wrong assumptions Claude made about how the mock should be used - I then directed it to fix that issue as well, and all tests passed.
- I then reverted everything and tried again with Copilot (just to see how it went)
- It created a bit fewer tests, but the difference was in less important areas.
- The tests compiled correctly, and a couple didn't pass because of wrong assumptions. Once told to correct the issues the tests passed.

**Results**

- We got a large amount of tests that cover many small use cases for legacy code (code without tests), increasing coverage and confidence in that code
- Claude created tests for things I didn't even think of.

**What Went Wrong**

- Claude initially created code that didn't even compile.
- Both Claude and Copilot created tests that didn't pass because of wrong assumptions about how the code works, but Copilot had a harder time with it because of lack of context.

**What We Learned**

- Directing the AI with small tasks works better than larger ones
- When making large enough changes, it is better to ask it to make a plan first and to change nothing yet, then review the plan and have it tweak and refine the plan until it produces the best results.

---

## Use Case 6: Organizing fixture files

**AI Tool Used:** Claude Code @Nimrod Argov  
**Project Context:** Dividing and organizing multiple fixture files into smaller building blocks so that they can be composed in tests without having to duplicate fixture data.  
**Primary Challenge:** Fixture data is hard to read because these are long JSON files, and it's easy to miss things. As time goes by, developers tend to add new fixture files that contain the same data again and again.

**AI Prompt / Approach**  
**Prompt or Task Given to Claude:**  
The following files \[list of files\] define rows in tables in a database, used for testing purposes. Each entry has a key value pair where the key is the database name and the value is an array of database rows, each of which is an object where each key is a column name and the value is the row value for that column.  
I would like to eliminate duplication in these files and divide existing large files into smaller ones to enable composition of test data for different tests.  
Create a list of duplications and proposed changes to the files.

**Approach Taken**

- For the first prompt, Claude created a list of duplicate entries. The list was very precise. It also created a list of changes it wanted to make, including creating new files and moving things from file to file.
- It didn't take into account the files being used in tests, however, and I had to show it how the fixture files are loaded and explain the loading mechanism.
- It then added missing files into the tests (and changed some).
- At this point some tests failed because the fixture files are versioned, and some file compositions were missing data that was previously there
- I explained the versioning issue, and Claude created duplications of the data conforming to the correct versions.

**Results**

- Fixture files were divided into smaller chunks that can now be used easily in tests without duplication. The amount of files had to be tweaked, but eventually came to a good result.

**What Went Wrong**

- Claude doesn't always understand context on its own, so initially without explaining things fully, it just did things wrong without regard to the rest of the code.
- If not specifying granularity, Claude has a hard time understanding what a good measure of small/large might be sometimes, and so it created too large/small files until we reached a good conclusion.

**What We Learned**

- Specificity is king - the more data you give Claude, the better the result will be.
- Having Claude review its own work sometimes yields better results after it fixes errors pointed out.
- Working on a large file set can produce hallucinations and Claude invents things that weren't there before - small steps work better.

---

## Use Case 7: Locating a Hidden Component in the UI with Claude

**AI Tool Used:** Claude Code @Michal Epshtein  
**Project Context:** Supporting a teammate during Millennium week refactoring work for the new Pitch design system  
**Primary Challenge:** Identifying where and how a specific legacy component appears in the UI, especially when unfamiliar with the product area and the component is hidden under specific conditions

**AI Prompt / Approach**

**Prompt or Task Given to Claude:**

> "I need to refactor this component: `WebFrontEndUI/src/r/js/pages/call/components/external-shares/components/AggregatedItem.jsx`, but I can't find it in the UI. It's likely hidden due to conditional rendering. Can you help me find out what needs to happen for it to appear, and guide me through the steps to see it?"

**Approach Taken:**

- Shared the file path with Claude
- Asked Claude to analyze the component code and determine what conditions control its visibility
- Requested a step-by-step UI flow to reproduce the scenario where the component is visible

**Results**

- Within 2 minutes, Claude accurately identified the relevant visibility conditions in the code
- Returned a clear explanation of what triggers the component display
- Provided a simple, actionable guide to replicate the scenario in the UI
- Saved significant time compared to manual tracing and guesswork

**What Went Wrong**

- Nothing major; Claude quickly understood the code and delivered a usable answer
- Some clarifying questions were needed to confirm edge cases

**What We Learned**

- Claude is highly effective at reverse-engineering component logic
- Ideal for unfamiliar code areas, especially when UI behaviors depend on complex conditions
- Simple prompts plus component paths can yield fast, actionable insights
- Great companion tool for developers during onboarding or context ramp-up tasks

---

## Use Case 8: Auto-Generating a Guided Tour for an Unknown Repo

**AI Tool Used:** Claude Code @Or Duer  
**Project Context:** Needed to ramp up on a backend service and a frontend component I wasn't familiar with  
**Primary Challenge:** Understanding project structure and architecture without prior knowledge or internal documentation

**AI Prompt / Approach**

**Prompt Given to Claude:**

```
<context>

  You are an experienced senior developer & onboarding mentor for the

  {{PROJECT_NAME}} team.

  The project is a {{PROJECT_TYPE}} built with {{TECH_STACK}}.

  Your goal is to give a clear, engaging, and actionable *guided tour* of the

  project's structure to a developer who is new to the code‑base, covering **both back‑end and front‑end** (if present).

</context>

<instruction>

  Lead the new developer through the project *step‑by‑step*:

  [Detailed architectural tour instructions here…]

</instruction>

<input>

  <project_overview>{{PROJECT_OVERVIEW}}</project_overview>

  ...

</input>

<output_format>

Produce **Markdown** containing these top‑level headings *in order*:

[Project Map → Walk-through Example → Hands-on Mini Tasks]

</output_format>
```

**Approach Taken:**

- Supplied the prompt above to Claude with a few edits depending on the repo type (backend vs. frontend)
- Used real directory structures and architecture inputs as available
- Tested on both a backend microservice and a large React component

**Results**

- Claude produced a well-structured, markdown-formatted onboarding guide
- The output gave a solid **high-level overview**, and explained **layered architecture**, **key modules**, and **data flow**
- For the backend service, results were highly accurate and actionable
- For the large frontend component, results were still helpful but included some **hallucinated details**, especially when architectural cues were sparse

**What Went Wrong**

- Some frontend outputs were incorrect (hallucinated internal details) — likely due to token limits and lack of available contextual cues
- Needed to tweak the prompt slightly depending on repo type (FE vs BE)

**What We Learned**

- This is a **powerful use case** for onboarding developers faster
- Claude can act like a senior onboarding buddy — surfacing structure, entry points, and key concepts
- Markdown format and modular output made it easy to share or use as internal docs
- Works best when project structure and naming conventions are clear
- Adding a few contextual hints (like tech stack and key entities) significantly improves output accuracy

---

## Use Case 9: Iterative Development with PR Context

**AI Tool Used:** Claude Code @Gal Morad  
**Project Context:** Creating utility methods for period conversion in a Gong-specific proprietary format and with fiscal dates logic.  
**Primary Challenge:** Implementing multiple similar period type conversions while maintaining consistency and code quality.

**Prompt or Task Given to Claude:**  
"Using this PR as context, implement \[another period type conversion\]" (provided PR link) Subsequent: "Implement one more period type using the same pattern"

**Approach Taken:**

- Created the first period conversion method with comprehensive tests
- Submitted a PR with the initial implementation
- Used the PR as rich context for Claude to understand the codebase structure, coding patterns, and testing approach
- Iteratively asked Claude to implement additional period types using the established pattern

**Results**

- Claude successfully implemented multiple period type conversions
- Maintained consistent code style and structure across all implementations
- Generated appropriate tests following the established patterns

**What Went Wrong**

- No major issues - the PR context provided excellent scaffolding

**What We Learned**

- PRs serve as excellent context for iterative development tasks
- Claude can effectively maintain consistency across similar implementations when given good examples

---

## Use Case 10: Using Jira as Your Planning Canvas

**AI Tool Used:** Claude Code java-architect agent + Jira MCP @Gal Morad  
**Project Context:** Complex development tasks requiring structured planning with persistent documentation  
**Primary Challenge:** Maintaining organized development workflow across multiple sessions

**AI Prompt / Approach**

**Prompt or Task Given to Claude:**

- "Help me plan this development task" (using java-architect agent)
- "Create a Jira task for this implementation with phases"
- "Implement phase 1 from this Jira: \[Jira URL\]"
- "Checkout branch by the branch name in the Jira, push and create PR"

**Approach Taken:**

- Used java-architect agent for task analysis and planning
- Broke down work into logical phases with Claude
- Created structured Jira task with documented phases
- Used Jira as persistent roadmap between sessions
- Referenced specific phases in prompts for focused implementation
- Automated git workflow (branch, push, PR creation)

**Results**

**What Went Wrong**

**What We Learned**

- Jira serves as excellent persistent context for AI development
- Breaking tasks into phases improves AI understanding and developer focus
- AI planning + project management tools creates sustainable workflows
- Git automation maintains development momentum