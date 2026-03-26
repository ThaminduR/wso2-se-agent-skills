---
name: analyze-issue
description: Validate whether a GitHub issue is a real bug and write the resolution to an analyze doc.
user-invocable: true
argument-hint: "[GitHub Issue URL]"
---

# Analyze Issue

The following product issue was reported: $ARGUMENTS.
Please validate whether it is a real bug. Do not assume the solutions given by the reporter are accurate. Independently come up with the correct resolution for this issue. When applicable verify against the code and relevant product, library, and technical documentation. Finally add the resolution to a .ai/issue-analysis.md doc.
