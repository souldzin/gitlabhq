---
stage: Verify
group: Pipeline Execution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference
---

# CI/CD minutes quota **(PREMIUM)**

[Shared runners](../runners/runners_scope.md#shared-runners) are shared with every project and group in a GitLab instance.
When jobs run on shared runners, CI/CD minutes are used.

You can set limits on the number of CI/CD minutes that are used each month.

- On GitLab.com, the quota of CI/CD minutes is set for each [namespace](../../user/group/index.md#namespaces),
  and is determined by [your license tier](https://about.gitlab.com/pricing/).
- On self-managed GitLab instances, the quota of CI/CD minutes for each namespace is set by administrators.

In addition to the monthly quota, you can add more CI/CD minutes when needed.

- On GitLab.com, you can [purchase additional CI/CD minutes](#purchase-additional-cicd-minutes).
- On self-managed GitLab instances, administrators can [assign more CI/CD minutes](#set-the-quota-of-cicd-minutes-for-a-specific-namespace).

[Specific runners](../runners/runners_scope.md#specific-runners)
are not subject to a quota of CI/CD minutes.

## Set the quota of CI/CD minutes for all namespaces

> [Moved](https://about.gitlab.com/blog/2021/01/26/new-gitlab-product-subscription-model/) to GitLab Premium in 13.9.

By default, GitLab instances do not have a quota of CI/CD minutes.
The default value for the quota is `0`, which grants unlimited CI/CD minutes.
However, you can change this default value.

Prerequisite:

- You must be a GitLab administrator.

To change the default quota that applies to all namespaces:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Settings > CI/CD**.
1. Expand **Continuous Integration and Deployment**.
1. In the **Quota of CI/CD minutes** box, enter the maximum number of CI/CD minutes.
1. Select **Save changes**.

If a quota is already defined for a specific namespace, this value does not change that quota.

## Set the quota of CI/CD minutes for a specific namespace

> [Moved](https://about.gitlab.com/blog/2021/01/26/new-gitlab-product-subscription-model/) to GitLab Premium in 13.9.

You can override the global value and set a quota of CI/CD minutes
for a specific namespace.

Prerequisite:

- You must be a GitLab administrator.

To set a quota of CI/CD minutes for a namespace:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Overview > Groups**.
1. For the group you want to update, select **Edit**.
1. In the **Quota of CI/CD minutes** box, enter the maximum number of CI/CD minutes.
1. Select **Save changes**.

You can also use the [update group API](../../api/groups.md#update-group) or the
[update user API](../../api/users.md#user-modification) instead.

NOTE:
You can set a quota of CI/CD minutes for only top-level groups or user namespaces.
If you set a quota for a subgroup, it is not used.

## View CI/CD minutes used by a group

> Displaying shared runners duration per project [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/355666) in GitLab 15.0.

You can view the number of CI/CD minutes being used by a group.

Prerequisite:

- You must have the Owner role for the group.

To view CI/CD minutes being used for your group:

1. On the top bar, select **Menu > Groups** and find your group. The group must not be a subgroup.
1. On the left sidebar, select **Settings > Usage Quotas**.
1. Select the **Pipelines** tab.

![Group CI/CD minutes quota](img/group_cicd_minutes_quota.png)

## View CI/CD minutes used by a personal namespace

> Displaying shared runners duration [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/345795) in GitLab 15.0.

You can view the number of CI/CD minutes being used by a personal namespace:

1. On the top bar, in the top right corner, select your avatar.
1. Select **Edit profile**.
1. On the left sidebar, select **Usage Quotas**.

## Purchase additional CI/CD minutes **(FREE SAAS)**

If you're using GitLab SaaS, you can purchase additional packs of CI/CD minutes.
These additional CI/CD minutes:

- Are used only after the monthly quota included in your subscription runs out.
- Are carried over to the next month, if any remain at the end of the month.
- Are valid for 12 months from date of purchase or until all minutes are consumed, whichever comes first. Expiry of minutes is not currently enforced.

If you use more CI/CD minutes than your monthly quota, when you purchase more,
those CI/CD minutes are deducted from your quota. For example, with a GitLab SaaS
Premium license:

- You have `10,000` monthly minutes.
- You purchase an additional `5,000` minutes.
- Your total limit is `15,000` minutes.

If you use `13,000` minutes during the month, the next month your additional minutes become
`2,000`. If you use `9,000` minutes during the month, your additional minutes remain the same.

You can find pricing for additional CI/CD minutes on the
[GitLab Pricing page](https://about.gitlab.com/pricing/).

### Purchase CI/CD minutes for a group **(FREE SAAS)**

You can purchase additional CI/CD minutes for your group.
You cannot transfer purchased CI/CD minutes from one group to another,
so be sure to select the correct group.

1. On the top bar, select **Menu > Groups** and find your group.
1. On the left sidebar, select **Settings > Usage Quotas**.
1. Select **Buy additional minutes**.
1. Complete the details of the transaction.

After your payment is processed, the additional CI/CD minutes are added to your group
namespace.

### Purchase CI/CD minutes for a personal namespace **(FREE SAAS)**

To purchase additional minutes for your personal namespace:

1. On the top bar, in the top right corner, select your avatar.
1. Select **Edit profile**.
1. On the left sidebar, select **Usage Quotas**.
1. Select **Buy additional minutes**. GitLab redirects you to the Customers Portal.
1. Locate the subscription card that's linked to your personal namespace on GitLab SaaS, select **Buy more CI minutes**,
   and complete the details of the transaction.

After your payment is processed, the additional CI/CD minutes are added to your personal
namespace.

## How CI/CD minutes are calculated

CI/CD minutes for individual jobs are calculated based on:

- The duration the job runs.
- The visibility of the projects where the job runs.

GitLab uses this formula to calculate CI/CD minutes consumed by a job:

```plaintext
Job duration * Cost factor
```

- **Job duration**: The time, in seconds, that a job took to run on a shared runner.
  It does not include time spent in `created` or `pending` status.
- **Cost factor**: A number based on project visibility.

The number is transformed into minutes and added to the overall quota in the job's top-level namespace.

For example:

- A user, `alice`, runs a pipeline under the `gitlab-org` namespace.
- The CI/CD minutes consumed by each job in the pipeline are added to the
  overall consumption for the `gitlab-org` namespace, not the `alice` namespace.
- If a pipeline runs for one of the personal projects for `alice`, the CI/CD minutes
  are added to the overall consumption for the `alice` namespace.

The CI/CD minutes used by one pipeline is the total CI/CD minutes used by all the jobs
that ran in the pipeline. The CI/CD minute usage for a pipeline can be higher than
the duration of the pipeline if many jobs ran at the same time.

### Cost factor

The cost factor for a job running on a shared runner is:

- `0.008` for public projects on GitLab SaaS, if [created 2021-07-17 or later](https://gitlab.com/gitlab-org/gitlab/-/issues/332708).
  (For every 125 minutes of job time, you accrue 1 CD/CD minute.)
- `0.008` for projects members of GitLab [Open Source program](../../subscriptions/index.md#gitlab-for-open-source).
  (For every 125 minutes of job time, you accrue 1 CD/CD minute.)
- `0` for public projects on GitLab self-managed instances, and for GitLab SaaS public projects created before 2021-07-17.
- `1` for internal and private projects.

### Additional costs on GitLab SaaS

GitLab SaaS shared runners have different cost factors, depending on the runner type (Linux, Windows, macOS) and the virtual machine configuration.

| GitLab SaaS runner type  | Virtual machine configuration   | CI/CD minutes cost factor  |
| :--------- | :------------------- | :--------- |
| Linux OS + Docker executor| 1 vCPU, 3.75 GB RAM   |1|
| macOS + shell executor   | 4 vCPU, 10 GB RAM| 6 |

### Monthly reset of CI/CD minutes

On the first day of each calendar month, the accumulated usage of CI/CD minutes is reset to `0`
for all namespaces that use shared runners. This means your full quota is available, and
calculations start again from `0`.

For example, if you have a monthly quota of `10,000` CI/CD minutes:

- On **1st April**, you have `10,000` minutes.
- During April, you use only `6,000` of the `10,000` minutes.
- On **1st May**, the accumulated usage of minutes resets to `0`, and you have `10,000` minutes to use again
  during May.

Usage data for the previous month is kept to show historical view of the consumption over time.

### Monthly rollover of purchased CI/CD minutes

If you purchase additional CI/CD minutes and don't use the full amount, the remaining amount rolls over to
the next month.

For example:

- On **1st April**, you purchase `5,000` CI/CD minutes.
- During April, you use only `3,000` of the `5,000` minutes.
- On **1st May**, the remaining `2,000` minutes roll over and are added to your monthly quota.

Additional CI/CD minutes are a one-time purchase and do not renew or refresh each month.

## What happens when you exceed the quota

When the quota of CI/CD minutes is used for the current month, GitLab stops
processing new jobs.

- Any non-running job that should be picked by shared runners is automatically dropped.
- Any job being retried is automatically dropped.
- Any running job can be dropped at any point if the overall namespace usage goes over-quota
  by a grace period.

The grace period for running jobs is `1,000` CI/CD minutes.

Jobs on specific runners are not affected by the quota of CI/CD minutes.

### GitLab SaaS usage notifications

On GitLab SaaS an email notification is sent to the namespace owners when:

- The available CI/CD minutes are below 30% of the quota.
- The available CI/CD minutes are below 5% of the quota.
- All CI/CD minutes have been used.

## Reduce consumption of CI/CD minutes

If your project consumes too many CI/CD minutes, there are some strategies you can
use to reduce your CI/CD minutes usage:

- If you are using project mirrors, ensure that [pipelines for mirror updates](../../user/project/repository/mirror/pull.md#trigger-pipelines-for-mirror-updates)
  is disabled.
- Reduce the frequency of [scheduled pipelines](schedules.md).
- [Skip pipelines](index.md#skip-a-pipeline) when not needed.
- Use [interruptible](../yaml/index.md#interruptible) jobs which can be auto-canceled
  if a new pipeline starts.
- If a job doesn't have to run in every pipeline, use [`rules`](../jobs/job_control.md)
  to make it only run when it's needed.
- [Use private runners](../runners/runners_scope.md#group-runners) for some jobs.
- If you are working from a fork and you submit a merge request to the parent project,
  you can ask a maintainer to run a pipeline [in the parent project](merge_request_pipelines.md#run-pipelines-in-the-parent-project).

If you manage an open source project, these improvements can also reduce CI/CD minutes
consumption for contributor fork projects, enabling more contributions.

See our [pipeline efficiency guide](pipeline_efficiency.md) for more details.
