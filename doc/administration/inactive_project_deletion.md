---
stage: Manage
group: Compliance
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Inactive project deletion **(FREE SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/85689) in GitLab 15.0 [with a flag](../administration/feature_flags.md) named `inactive_projects_deletion`. Disabled by default.

FLAG:
On self-managed GitLab, by default this feature is not available. To make it available, ask an administrator to
[enable the feature flag](../administration/feature_flags.md) named `inactive_projects_deletion`.
On GitLab.com, this feature is not available. This feature is not ready for production use.

Administrators of large GitLab instances can find that over time, projects become inactive and are no longer used.
These projects take up unnecessary disk space. With inactive project deletion, you can identify these projects, warn
the maintainers ahead of time, and then delete the projects if they remain inactive. When an inactive project is
deleted, the action generates an audit event that it was performed by the first active administrator.

## Configure inactive project deletion

You can configure inactive projects deletion or turn it off using the
[Application settings API](../api/settings.md#change-application-settings).

The following options are available:

- `delete_inactive_projects`: Enable or disable inactive project deletion.
- `inactive_projects_min_size_mb`: Minimum size (MB) of inactive projects to be considered for deletion.
  Projects smaller in size than this threshold aren't considered inactive.
- `inactive_projects_delete_after_months`: Minimum duration (months) after which a project is scheduled for deletion if
  it continues be inactive.
- `inactive_projects_send_warning_email_after_months`: Minimum duration (months) after which a deletion warning email is
  sent if a project continues to be inactive. The warning email is sent to users with the Owner and Maintainer roles of
  the inactive project. This duration should be less than the `inactive_projects_delete_after_months` duration.

For example:

- `delete_inactive_projects` enabled.
- `inactive_projects_min_size_mb` set to `50`.
- `inactive_projects_delete_after_months` set to `12`.
- `inactive_projects_send_warning_email_after_months` set to `6`.

In this scenario, when a project's size is:

- Less than 50 MB, the project is not considered inactive.
- Greater than 50 MB and it is inactive for:
  - More than 6 months, a deletion warning is email is sent to users with the Owner and Maintainer role on the project
    with the scheduled date of deletion.
  - More than 12 months, the project is scheduled for deletion.

## Determine when a project was last active

You can view a project's activities and determine when the project was last active in the following ways:

1. Go to the [activity page](../user/project/working_with_projects.md#view-project-activity) for the project and view
   the date of the latest event.
1. View the `last_activity_at` attribute for the project using the [Projects API](../api/projects.md).
1. List the visible events for the project using the [Events API](../api/events.md#list-a-projects-visible-events).
   View the `created_at` attribute of the latest event.
