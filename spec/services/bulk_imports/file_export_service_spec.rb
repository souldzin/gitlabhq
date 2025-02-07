# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::FileExportService do
  let_it_be(:project) { create(:project) }
  let_it_be(:export_path) { Dir.mktmpdir }

  let(:relation) { BulkImports::FileTransfer::BaseConfig::UPLOADS_RELATION }

  subject(:service) { described_class.new(project, export_path, relation) }

  describe '#execute' do
    it 'executes export service and archives exported data' do
      expect_next_instance_of(BulkImports::UploadsExportService) do |service|
        expect(service).to receive(:execute)
      end

      expect(subject).to receive(:tar_cf).with(archive: File.join(export_path, 'uploads.tar'), dir: export_path)

      subject.execute
    end

    context 'when relation is lfs objects' do
      let(:relation) { BulkImports::FileTransfer::ProjectConfig::LFS_OBJECTS_RELATION }

      it 'executes lfs objects export service' do
        expect_next_instance_of(BulkImports::LfsObjectsExportService) do |service|
          expect(service).to receive(:execute)
        end

        expect(subject).to receive(:tar_cf).with(archive: File.join(export_path, 'lfs_objects.tar'), dir: export_path)

        subject.execute
      end
    end

    context 'when relation is repository bundle' do
      let(:relation) { BulkImports::FileTransfer::ProjectConfig::REPOSITORY_BUNDLE_RELATION }

      it 'executes repository bundle export service' do
        expect_next_instance_of(BulkImports::RepositoryBundleExportService) do |service|
          expect(service).to receive(:execute)
        end

        expect(subject)
          .to receive(:tar_cf)
          .with(archive: File.join(export_path, 'repository_bundle.tar'), dir: export_path)

        subject.execute
      end
    end

    context 'when unsupported relation is passed' do
      it 'raises an error' do
        service = described_class.new(project, export_path, 'unsupported')

        expect { service.execute }.to raise_error(BulkImports::Error, 'Unsupported relation export type')
      end
    end
  end

  describe '#exported_filename' do
    it 'returns filename of the exported file' do
      expect(subject.exported_filename).to eq('uploads.tar')
    end
  end
end
