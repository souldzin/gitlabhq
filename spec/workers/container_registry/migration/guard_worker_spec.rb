# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Migration::GuardWorker, :aggregate_failures do
  let(:worker) { described_class.new }

  describe '#perform' do
    let(:pre_importing_migrations) { ::ContainerRepository.with_migration_states(:pre_importing) }
    let(:pre_import_done_migrations) { ::ContainerRepository.with_migration_states(:pre_import_done) }
    let(:importing_migrations) { ::ContainerRepository.with_migration_states(:importing) }
    let(:import_aborted_migrations) { ::ContainerRepository.with_migration_states(:import_aborted) }
    let(:import_done_migrations) { ::ContainerRepository.with_migration_states(:import_done) }
    let(:import_skipped_migrations) { ::ContainerRepository.with_migration_states(:import_skipped) }

    subject { worker.perform }

    before do
      stub_container_registry_config(enabled: true, api_url: 'http://container-registry', key: 'spec/fixtures/x509_certificate_pk.key')
      allow(::ContainerRegistry::Migration).to receive(:max_step_duration).and_return(5.minutes)
    end

    context 'on gitlab.com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      shared_examples 'handling long running migrations' do |timeout:|
        before do
          allow_next_found_instance_of(ContainerRepository) do |repository|
            allow(repository).to receive(:migration_cancel).and_return(migration_cancel_response)
          end
        end

        shared_examples 'aborting the migration' do
          it 'will abort the migration' do
            expect(worker).to receive(:log_extra_metadata_on_done).with(:stale_migrations_count, 1)
            expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_stale_migrations_count, 1)
            expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_long_running_migration_ids, [stale_migration.id])
            expect(ContainerRegistry::Migration).to receive(timeout).and_call_original

            expect { subject }
                .to change(import_aborted_migrations, :count).by(1)
                .and change { stale_migration.reload.migration_state }.to('import_aborted')
                .and not_change { ongoing_migration.migration_state }
          end

          context 'registry_migration_guard_thresholds feature flag disabled' do
            before do
              stub_feature_flags(registry_migration_guard_thresholds: false)
            end

            it 'falls back on the hardcoded value' do
              expect(ContainerRegistry::Migration).not_to receive(:pre_import_timeout)

              expect { subject }
                .to change { stale_migration.reload.migration_state }.to('import_aborted')
            end
          end
        end

        context 'migration is canceled' do
          let(:migration_cancel_response) { { status: :ok } }

          before do
            stub_application_setting(container_registry_import_max_retries: 3)
          end

          context 'when the retry limit has been reached' do
            before do
              stale_migration.update_column(:migration_retries_count, 2)
            end

            it 'will not abort the migration' do
              expect(worker).to receive(:log_extra_metadata_on_done).with(:stale_migrations_count, 1)
              expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_stale_migrations_count, 1)
              expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_long_running_migration_ids, [stale_migration.id])
              expect(ContainerRegistry::Migration).to receive(timeout).and_call_original

              expect { subject }
                  .to change(import_skipped_migrations, :count)

              expect(stale_migration.reload.migration_state).to eq('import_skipped')
              expect(stale_migration.reload.migration_skipped_reason).to eq('migration_canceled')
            end

            context 'registry_migration_guard_thresholds feature flag disabled' do
              before do
                stub_feature_flags(registry_migration_guard_thresholds: false)
              end

              it 'falls back on the hardcoded value' do
                expect(ContainerRegistry::Migration).not_to receive(timeout)

                expect { subject }
                  .to change { stale_migration.reload.migration_state }.to('import_skipped')
              end
            end
          end

          context 'when the retry limit has not been reached' do
            it_behaves_like 'aborting the migration'
          end
        end

        context 'migration cancelation fails with an error' do
          let(:migration_cancel_response) { { status: :error } }

          it_behaves_like 'aborting the migration'
        end

        context 'migration receives bad request with a new status' do
          let(:migration_cancel_response) { { status: :bad_request, migration_state: :import_done } }

          it_behaves_like 'aborting the migration'
        end
      end

      context 'with no stale migrations' do
        it_behaves_like 'an idempotent worker'

        it 'will not update any migration state' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:stale_migrations_count, 0)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_stale_migrations_count, 0)

          expect { subject }
            .to not_change(pre_importing_migrations, :count)
            .and not_change(pre_import_done_migrations, :count)
            .and not_change(importing_migrations, :count)
            .and not_change(import_aborted_migrations, :count)
        end
      end

      context 'with pre_importing stale migrations' do
        let(:ongoing_migration) { create(:container_repository, :pre_importing) }
        let(:stale_migration) { create(:container_repository, :pre_importing, migration_pre_import_started_at: 11.minutes.ago) }
        let(:import_status) { 'test' }

        before do
          allow_next_instance_of(ContainerRegistry::GitlabApiClient) do |client|
            allow(client).to receive(:import_status).and_return(import_status)
          end

          stub_application_setting(container_registry_pre_import_timeout: 10.minutes.to_i)
        end

        it 'will abort the migration' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:stale_migrations_count, 1)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_stale_migrations_count, 1)

          expect { subject }
              .to change(pre_importing_migrations, :count).by(-1)
              .and not_change(pre_import_done_migrations, :count)
              .and not_change(importing_migrations, :count)
              .and not_change(import_done_migrations, :count)
              .and change(import_aborted_migrations, :count).by(1)
              .and change { stale_migration.reload.migration_state }.from('pre_importing').to('import_aborted')
              .and not_change { ongoing_migration.migration_state }
        end

        context 'the client returns pre_import_in_progress' do
          let(:import_status) { 'pre_import_in_progress' }

          it_behaves_like 'handling long running migrations', timeout: :pre_import_timeout
        end
      end

      context 'with pre_import_done stale migrations' do
        let(:ongoing_migration) { create(:container_repository, :pre_import_done) }
        let(:stale_migration) { create(:container_repository, :pre_import_done, migration_pre_import_done_at: 11.minutes.ago) }

        before do
          allow(::ContainerRegistry::Migration).to receive(:max_step_duration).and_return(5.minutes)
        end

        it 'will abort the migration' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:stale_migrations_count, 1)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_stale_migrations_count, 1)

          expect { subject }
              .to not_change(pre_importing_migrations, :count)
              .and change(pre_import_done_migrations, :count).by(-1)
              .and not_change(importing_migrations, :count)
              .and not_change(import_done_migrations, :count)
              .and change(import_aborted_migrations, :count).by(1)
              .and change { stale_migration.reload.migration_state }.from('pre_import_done').to('import_aborted')
              .and not_change { ongoing_migration.migration_state }
        end
      end

      context 'with importing stale migrations' do
        let(:ongoing_migration) { create(:container_repository, :importing) }
        let(:stale_migration) { create(:container_repository, :importing, migration_import_started_at: 11.minutes.ago) }
        let(:import_status) { 'test' }

        before do
          allow_next_instance_of(ContainerRegistry::GitlabApiClient) do |client|
            allow(client).to receive(:import_status).and_return(import_status)
          end

          stub_application_setting(container_registry_import_timeout: 10.minutes.to_i)
        end

        it 'will abort the migration' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:stale_migrations_count, 1)
          expect(worker).to receive(:log_extra_metadata_on_done).with(:aborted_stale_migrations_count, 1)

          expect { subject }
              .to not_change(pre_importing_migrations, :count)
              .and not_change(pre_import_done_migrations, :count)
              .and change(importing_migrations, :count).by(-1)
              .and not_change(import_done_migrations, :count)
              .and change(import_aborted_migrations, :count).by(1)
              .and change { stale_migration.reload.migration_state }.from('importing').to('import_aborted')
              .and not_change { ongoing_migration.migration_state }
        end

        context 'the client returns import_in_progress' do
          let(:import_status) { 'import_in_progress' }

          it_behaves_like 'handling long running migrations', timeout: :import_timeout
        end
      end
    end

    context 'not on gitlab.com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(false)
      end

      it 'is a no op' do
        expect(::ContainerRepository).not_to receive(:with_stale_migration)
        expect(worker).not_to receive(:log_extra_metadata_on_done)

        subject
      end
    end
  end

  describe 'worker attributes' do
    it 'has deduplication set' do
      expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
      expect(described_class.get_deduplication_options).to include(ttl: 5.minutes)
    end
  end
end
