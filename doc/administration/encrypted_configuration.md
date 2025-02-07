---
stage: Enablement
group: Distribution
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments"
type: reference
---

# Encrypted Configuration **(FREE SELF)**

> [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/45712) in GitLab 13.7.

GitLab can read settings for certain features from encrypted settings files. The supported features are:

- [LDAP `bind_dn` and `password`](auth/ldap/index.md#use-encrypted-credentials).
- [SMTP `user_name` and `password`](raketasks/smtp.md#secrets).

In order to enable the encrypted configuration settings, a new base key needs to be generated for
`encrypted_settings_key_base`. The secret can be generated in the following ways:

**Omnibus Installation**

Starting with 13.7 the new secret is automatically generated for you, but you need to ensure your
`/etc/gitlab/gitlab-secrets.json` contains the same values on all nodes.

**GitLab Cloud Native Helm Chart**

Starting with GitLab 13.7, the new secret is automatically generated if you have the `shared-secrets` chart enabled. Otherwise, you need
to follow the [secrets guide for adding the secret](https://docs.gitlab.com/charts/installation/secrets.html#gitlab-rails-secret).

**Source Installation**

The new secret can be generated by running:

```shell
bundle exec rake gitlab:env:info RAILS_ENV=production GITLAB_GENERATE_ENCRYPTED_SETTINGS_KEY_BASE=true
```

This prints general information on the GitLab instance, but also causes the key to be generated in `<path-to-gitlab-rails>/config/secrets.yml`.
