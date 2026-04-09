# What Strategy I Would Use to Make My Product's Software Development Efficient

I was thinking about this — if I'm a product owner, what strategy would I use to leverage AI to make software development efficient? This is what I would try. I'm laying out the strategy for bug fixing, but this is similar to features as well with some changes.

## The Workflow

When a bug issue is created, an **ANALYZE_AND_REPRODUCE** agent will automatically kick in. It will try to reproduce the bug and comment on the issue with its verdict — whether this is actually a bug or a false positive — along with some extra details: potential root cause, potential fix. If it's not reproducible, it will ask the issue creator further questions for more detailed steps, or pinpoint a problem in the provided steps.

Then, as a product expert, I review the issue and the agent's response and make the decision. If the verdict is true positive, I decide whether this issue should be assigned to AI or a human. If the fix is tricky, touches a crucial part of the system, or I'm not confident that the agent found the correct root cause or the correct approach to fix — I will assign a human to own and fix the bug. If it's something I'm confident AI can fix, I will assign the **FIX** agent.

Once a PR is produced, whether from a human or an agent, a **QA/QE/CODE_QUALITY** agent automatically starts working on the PR to verify that the fix actually fixes the problem and the code produced is a quality one.

Once the verdict is available on the PR, it is still the responsibility of a product expert to approve this PR.

## Why I'm Not Comfortable With Either Extreme

Why not **A.** assign all the issues to AI, or **B.** assign all the issues to developers and ask them to use these agents locally?

### A — Why Not Give Everything to AI?

The knowledge base of the product in an AI-readable form is not there yet. It's impossible for an AI to fix bugs in a way that takes into consideration all the decisions we made throughout the development of the product — the decisions we made in meeting rooms and emails, that suboptimal pattern we still keep in our codebase to support a backward-compatible feature, and so on.

### B — Why Not Give Everything to Developers With Predefined AI Skills/Agents?

The problem with asking developers to run these agents locally is that, over time, they will start treating all issues the same way. If I assign all issues to developers and also hand them predefined AI skills to execute, using those skills becomes the path of least resistance. The workflow is low friction, and since it's provided by the product owner, developers naturally start thinking — if the skill produces a suboptimal solution, it's still a solution created by a workflow the product owner gave me. Over time, the extra effort — reading docs, checking the architecture, chatting with a code owner about why something was written a certain way — gets skipped. On top of that, this approach naturally raises the expectation that developers should deliver faster, which means more issues get assigned to them, which further reinforces the cycle. A natural state gets created where speed is the priority, and the predefined workflow becomes the only workflow. The result is sloppy code, deviated architecture, and performance degradation along critical paths. The quality of the product takes the hit.

As an expert, if I make a decision that an issue should be handled by a human, that means I really need a human touch to resolve it. Even in that case, I do not want the developers to fall back on predefined AI skills or workflows to make the analysis or find the fix.

## The Benefit of Separation

In this way, by separating the issues between agents and developers, my developers know that if an issue is coming to their hand, they need to carefully investigate — by reading related docs, understanding the architecture around it, understanding the reason behind why the code was written that way in the first place, and meeting with people to explore and gain more knowledge.

On the other side, by routing straightforward fixes and features to AI, I keep my developers from wasting their valuable time on routine work that doesn't need their expertise. Their time is better spent on the problems that actually demand human judgment.
