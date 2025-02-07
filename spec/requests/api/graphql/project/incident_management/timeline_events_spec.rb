# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting incident timeline events' do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:updated_by_user) { create(:user) }
  let_it_be(:incident) { create(:incident, project: project) }
  let_it_be(:another_incident) { create(:incident, project: project) }
  let_it_be(:promoted_from_note) { create(:note, project: project, noteable: incident) }

  let_it_be(:timeline_event) do
    create(
      :incident_management_timeline_event,
      incident: incident,
      project: project,
      updated_by_user: updated_by_user,
      promoted_from_note: promoted_from_note
    )
  end

  let_it_be(:second_timeline_event) do
    create(:incident_management_timeline_event, incident: incident, project: project)
  end

  let_it_be(:another_timeline_event) do
    create(:incident_management_timeline_event, incident: another_incident, project: project)
  end

  let(:params) { { incident_id: incident.to_global_id.to_s } }

  let(:timeline_event_fields) do
    <<~QUERY
      nodes {
        id
        author { id username }
        updatedByUser { id username }
        incident { id title }
        note
        noteHtml
        promotedFromNote { id body }
        editable
        action
        occurredAt
        createdAt
        updatedAt
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('incidentManagementTimelineEvents', params, timeline_event_fields)
    )
  end

  let(:timeline_events) do
    graphql_data.dig('project', 'incidentManagementTimelineEvents', 'nodes')
  end

  before do
    project.add_guest(current_user)
    post_graphql(query, current_user: current_user)
  end

  it_behaves_like 'a working graphql query'

  it 'returns the correct number of timeline events' do
    expect(timeline_events.count).to eq(2)
  end

  it 'returns the correct properties of the incident timeline events' do
    expect(timeline_events.first).to include(
      'author' => {
        'id' => timeline_event.author.to_global_id.to_s,
        'username' => timeline_event.author.username
      },
      'updatedByUser' => {
        'id' => updated_by_user.to_global_id.to_s,
        'username' => updated_by_user.username
      },
      'incident' => {
        'id' => incident.to_global_id.to_s,
        'title' => incident.title
      },
      'note' => timeline_event.note,
      'noteHtml' => timeline_event.note_html,
      'promotedFromNote' => {
        'id' => promoted_from_note.to_global_id.to_s,
        'body' => promoted_from_note.note
      },
      'editable' => false,
      'action' => timeline_event.action,
      'occurredAt' => timeline_event.occurred_at.iso8601,
      'createdAt' => timeline_event.created_at.iso8601,
      'updatedAt' => timeline_event.updated_at.iso8601
    )
  end

  context 'when filtering by id' do
    let(:params) { { incident_id: incident.to_global_id.to_s, id: timeline_event.to_global_id.to_s } }

    let(:query) do
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_graphql_field('incidentManagementTimelineEvent', params, 'id occurredAt')
      )
    end

    it_behaves_like 'a working graphql query'

    it 'returns a single timeline event', :aggregate_failures do
      single_timeline_event = graphql_data.dig('project', 'incidentManagementTimelineEvent')

      expect(single_timeline_event).to include(
        'id' => timeline_event.to_global_id.to_s,
        'occurredAt' => timeline_event.occurred_at.iso8601
      )
    end
  end
end
