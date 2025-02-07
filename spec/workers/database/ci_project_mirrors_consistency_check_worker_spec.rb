# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Database::CiProjectMirrorsConsistencyCheckWorker do
  let(:worker) { described_class.new }

  describe '#perform' do
    context 'feature flag is disabled' do
      before do
        stub_feature_flags(ci_project_mirrors_consistency_check: false)
      end

      it 'does not perform the consistency check on projects' do
        expect(Database::ConsistencyCheckService).not_to receive(:new)
        expect(worker).not_to receive(:log_extra_metadata_on_done)
        worker.perform
      end
    end

    context 'feature flag is enabled' do
      before do
        stub_feature_flags(ci_project_mirrors_consistency_check: true)
      end

      it 'executes the consistency check on projects' do
        expect(Database::ConsistencyCheckService).to receive(:new).and_call_original
        expected_result = { batches: 0, matches: 0, mismatches: 0, mismatches_details: [] }
        expect(worker).to receive(:log_extra_metadata_on_done).with(:results, expected_result)
        worker.perform
      end
    end

    context 'logs should contain the detailed mismatches' do
      let(:first_project) { Project.all.order(:id).limit(1).first }
      let(:missing_project) { Project.all.order(:id).limit(2).last }

      before do
        redis_shared_state_cleanup!
        stub_feature_flags(ci_project_mirrors_consistency_check: true)
        create_list(:project, 10) # This will also create Ci::ProjectMirror objects
        missing_project.delete

        allow_next_instance_of(Database::ConsistencyCheckService) do |instance|
          allow(instance).to receive(:random_start_id).and_return(Project.first.id)
        end
      end

      it 'reports the differences to the logs' do
        expected_result = {
          batches: 1,
          matches: 9,
          mismatches: 1,
          mismatches_details: [{
            id: missing_project.id,
            source_table: nil,
            target_table: [missing_project.namespace_id]
          }],
          start_id: first_project.id,
          next_start_id: first_project.id # The batch size > number of projects
        }
        expect(worker).to receive(:log_extra_metadata_on_done).with(:results, expected_result)
        worker.perform
      end

      it 'calls the consistency_fix_service to fix the inconsistencies' do
        expect_next_instance_of(Database::ConsistencyFixService) do |instance|
          expect(instance).to receive(:execute).with(
            ids: [missing_project.id]
          ).and_call_original
        end
        worker.perform
      end
    end
  end
end
