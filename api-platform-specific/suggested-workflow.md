# Issue Reproduction & Fix Workflow

When working on the issue, prompt the CC in a fresh context:

## Step 1: Analyze the Issue

**PROMPT:**

> The following product issue was reported: https://github.com/wso2/api-platform/issues/1474.
> Please validate whether it is a real bug. Do not assume the solutions given by the reporter are accurate. Independently come up with the correct resolution for this issue. When applicable, verify against the code and relevant product, library, and technical documentation. Finally, add the resolution to an analyze doc.

---

## Step 2: Validate the Analysis

Clear the context.

**PROMPT:**

> Validate the @analyze doc by running the product.

- If **false positive** and we confirm it, we can close the issue.
- If **true positive**, proceed to Step 3.

---

## Step 3: Plan the Fix

Clear the context. Go to plan mode.

**PROMPT:**

> Based on the @analyze doc, plan a fix and a testing strategy. This should include unit and integration tests.

Approve the plan or modify it.

---

## Step 4: Run Tests

Once the fix is done:

**PROMPT:**

> Run the unit and integration tests you have added.

---

## Step 5: Manual Verification

Once they have passed:

**PROMPT:**

> Show me the steps to manually verify the fix, starting with how to build, how to update the compose file with rebuilt images, and the steps to confirm that the initial bug is fixed.