# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Navigation bar counter', :use_clean_rails_memory_store_caching do
  let(:user) { create(:user) }
  let(:project) { create(:project, namespace: user.namespace) }
  let(:issue) { create(:issue, project: project) }
  let(:merge_request) { create(:merge_request, source_project: project) }

  describe 'feature flag mr_attention_requests is disabled' do
    before do
      stub_feature_flags(mr_attention_requests: false)

      issue.assignees = [user]
      merge_request.update!(assignees: [user])
      sign_in(user)
    end

    it 'reflects dashboard issues count' do
      visit issues_path

      expect_counters('issues', '1', n_("%d assigned issue", "%d assigned issues", 1) % 1)

      issue.assignees = []

      user.invalidate_cache_counts

      travel_to(3.minutes.from_now) do
        visit issues_path

        expect_counters('issues', '0', n_("%d assigned issue", "%d assigned issues", 0) % 0)
      end
    end

    it 'reflects dashboard merge requests count', :js do
      visit merge_requests_path

      expect_counters('merge_requests', '1', n_("%d merge request", "%d merge requests", 1) % 1)

      merge_request.update!(assignees: [])

      user.invalidate_cache_counts

      travel_to(3.minutes.from_now) do
        visit merge_requests_path

        expect_counters('merge_requests', '0', n_("%d merge request", "%d merge requests", 0) % 0)
      end
    end
  end

  describe 'feature flag mr_attention_requests is enabled' do
    before do
      merge_request.update!(assignees: [user])

      merge_request.find_assignee(user).update!(state: :attention_requested)

      user.invalidate_attention_requested_count

      sign_in(user)
    end

    it 'reflects dashboard merge requests count', :js do
      visit merge_requests_attention_path

      expect_counters('merge_requests', '1', n_("%d merge request", "%d merge requests", 1) % 1)

      merge_request.find_assignee(user).update!(state: :reviewed)

      user.invalidate_attention_requested_count

      travel_to(3.minutes.from_now) do
        visit merge_requests_attention_path

        expect_counters('merge_requests', '0', n_("%d merge request", "%d merge requests", 0) % 0)
      end
    end
  end

  def issues_path
    issues_dashboard_path(assignee_username: user.username)
  end

  def merge_requests_path
    merge_requests_dashboard_path(assignee_username: user.username)
  end

  def merge_requests_attention_path
    merge_requests_dashboard_path(attention: user.username)
  end

  def expect_counters(issuable_type, count, badge_label)
    dashboard_count = find('.gl-tabs-nav li a.active')

    expect(dashboard_count).to have_content(count)
    expect(page).to have_css(".dashboard-shortcuts-#{issuable_type}", visible: :all, text: count)
    expect(page).to have_css("span[aria-label='#{badge_label}']", visible: :all, text: count)
  end
end
