# frozen_string_literal: true

class WorkItemPolicy < IssuePolicy
  condition(:is_member_and_author) { is_project_member? & is_author? }

  rule { can?(:destroy_issue) | is_member_and_author }.enable :delete_work_item

  rule { can?(:update_issue) }.enable :update_work_item

  rule { can?(:read_issue) }.enable :read_work_item
end
