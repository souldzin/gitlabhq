# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting issues crm contacts' do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :crm_enabled) }
  let_it_be(:subgroup) { create(:group, :crm_enabled, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:contacts) { create_list(:contact, 4, group: group) }

  let(:issue) { create(:issue, project: project) }
  let(:operation_mode) { Types::MutationOperationModeEnum.default_mode }
  let(:initial_contacts) { contacts[0..1] }
  let(:mutation_contacts) { contacts[1..2] }
  let(:contact_ids) { mutation_contacts.map { global_id_of(_1) } }
  let(:does_not_exist_or_no_permission) { "The resource that you are attempting to access does not exist or you don't have permission to perform this action" }

  let(:mutation) do
    variables = {
      project_path: issue.project.full_path,
      iid: issue.iid.to_s,
      operation_mode: operation_mode,
      contact_ids: contact_ids
    }

    graphql_mutation(:issue_set_crm_contacts, variables,
                     <<-QL.strip_heredoc
                       clientMutationId
                       errors
                       issue {
                         customerRelationsContacts {
                           nodes {
                             id
                           }
                         }
                       }
                     QL
    )
  end

  def mutation_response
    graphql_mutation_response(:issue_set_crm_contacts)
  end

  def expected_contacts(contacts)
    contacts.map { |contact| a_graphql_entity_for(contact) }
  end

  before do
    initial_contacts.each { |contact| create(:issue_customer_relations_contact, issue: issue, contact: contact) }
  end

  shared_examples 'successful mutation' do
    context 'replace' do
      it 'updates the issue with correct contacts' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :issue, :customer_relations_contacts, :nodes))
          .to match_array(expected_contacts(mutation_contacts))
      end
    end

    context 'append' do
      let(:mutation_contacts) { [contacts[3]] }
      let(:operation_mode) { Types::MutationOperationModeEnum.enum[:append] }

      it 'updates the issue with correct contacts' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :issue, :customer_relations_contacts, :nodes))
          .to match_array(expected_contacts(initial_contacts + mutation_contacts))
      end
    end

    context 'remove' do
      let(:mutation_contacts) { [contacts[0]] }
      let(:operation_mode) { Types::MutationOperationModeEnum.enum[:remove] }

      it 'updates the issue with correct contacts' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :issue, :customer_relations_contacts, :nodes))
          .to match_array(expected_contacts(initial_contacts - mutation_contacts))
      end
    end
  end

  context 'when the user has no permission' do
    it 'returns expected error' do
      error = Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR
      post_graphql_mutation(mutation, current_user: user)

      expect(graphql_errors).to include(a_hash_including('message' => error))
    end
  end

  context 'when the user has permission' do
    before do
      group.add_reporter(user)
    end

    context 'when the feature is disabled' do
      before do
        stub_feature_flags(customer_relations: false)
      end

      it 'raises expected error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_errors).to include(a_hash_including('message' => 'Feature disabled'))
      end
    end

    it_behaves_like 'successful mutation'

    context 'when the contact does not exist' do
      let(:contact_ids) { [global_id_of(model_name: 'CustomerRelations::Contact', id: non_existing_record_id)] }

      it 'returns expected error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :errors))
          .to match_array(["Issue customer relations contacts #{non_existing_record_id}: #{does_not_exist_or_no_permission}"])
      end
    end

    context 'when the contact belongs to a different group' do
      let(:group2) { create(:group, :crm_enabled) }
      let(:contact) { create(:contact, group: group2) }
      let(:contact_ids) { [global_id_of(contact)] }

      before do
        group2.add_reporter(user)
      end

      it 'returns expected error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :errors))
        .to match_array(["Issue customer relations contacts #{contact.id}: #{does_not_exist_or_no_permission}"])
      end
    end

    context 'when attempting to add more than 6' do
      let(:operation_mode) { Types::MutationOperationModeEnum.enum[:append] }
      let(:gid) { global_id_of(contacts[0]) }
      let(:contact_ids) { [gid, gid, gid, gid, gid, gid, gid] }

      it 'returns expected error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :errors))
          .to match_array(["You can only add up to 6 contacts at one time"])
      end
    end

    context 'when trying to remove non-existent contact' do
      let(:operation_mode) { Types::MutationOperationModeEnum.enum[:remove] }
      let(:contact_ids) { [global_id_of(model_name: 'CustomerRelations::Contact', id: non_existing_record_id)] }

      it 'raises expected error' do
        post_graphql_mutation(mutation, current_user: user)

        expect(graphql_data_at(:issue_set_crm_contacts, :errors)).to be_empty
      end
    end
  end

  context 'when crm_enabled is false' do
    let(:issue) { create(:issue) }
    let(:initial_contacts) { [] }

    it 'raises expected error' do
      issue.project.add_reporter(user)

      post_graphql_mutation(mutation, current_user: user)

      expect(graphql_errors).to include(a_hash_including('message' => 'Feature disabled'))
    end
  end
end
