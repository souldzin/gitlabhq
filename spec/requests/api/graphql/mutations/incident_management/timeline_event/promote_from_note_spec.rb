# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Promote an incident timeline event from a comment' do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:incident) { create(:incident, project: project) }
  let_it_be(:comment) { create(:note, project: project, noteable: incident) }

  let(:input) { { note_id: comment.to_global_id.to_s } }
  let(:mutation) do
    graphql_mutation(:timeline_event_promote_from_note, input) do
      <<~QL
        clientMutationId
        errors
        timelineEvent {
          author { id username }
          incident { id title }
          promotedFromNote { id }
          note
          action
          editable
          occurredAt
        }
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:timeline_event_promote_from_note) }

  before do
    project.add_developer(user)
  end

  it 'creates incident timeline event from the note', :aggregate_failures do
    post_graphql_mutation(mutation, current_user: user)

    timeline_event_response = mutation_response['timelineEvent']

    expect(response).to have_gitlab_http_status(:success)
    expect(timeline_event_response).to include(
      'author' => {
        'id' => user.to_global_id.to_s,
        'username' => user.username
      },
      'incident' => {
        'id' => incident.to_global_id.to_s,
        'title' => incident.title
      },
      'promotedFromNote' => {
        'id' => comment.to_global_id.to_s
      },
      'note' => comment.note,
      'action' => 'comment',
      'editable' => false,
      'occurredAt' => comment.created_at.iso8601
    )
  end
end
