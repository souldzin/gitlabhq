# frozen_string_literal: true

RSpec.shared_examples 'successful response for #cancel_auto_stop' do
  include GitlabRoutingHelper

  context 'when request is html' do
    let(:params) { environment_params(format: :html) }

    it 'redirects to show page' do
      subject

      expect(response).to redirect_to(environment_path(environment))
      expect(flash[:notice]).to eq('Auto stop successfully canceled.')
    end

    it 'expires etag caching' do
      expect_next_instance_of(Gitlab::EtagCaching::Store) do |etag_caching|
        expect(etag_caching).to receive(:touch).with(project_environments_path(project, format: :json))
      end

      subject
    end
  end

  context 'when request is js' do
    let(:params) { environment_params(format: :json) }

    it 'responds as ok' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['message']).to eq('Auto stop successfully canceled.')
    end

    it 'expires etag caching' do
      expect_next_instance_of(Gitlab::EtagCaching::Store) do |etag_caching|
        expect(etag_caching).to receive(:touch).with(project_environments_path(project, format: :json))
      end

      subject
    end
  end
end

RSpec.shared_examples 'failed response for #cancel_auto_stop' do
  context 'when request is html' do
    let(:params) { environment_params(format: :html) }

    it 'redirects to show page' do
      subject

      expect(response).to redirect_to(environment_path(environment))
      expect(flash[:alert]).to eq("Failed to cancel auto stop because #{message}.")
    end
  end

  context 'when request is js' do
    let(:params) { environment_params(format: :json) }

    it 'responds as unprocessable entity' do
      subject

      expect(response).to have_gitlab_http_status(:unprocessable_entity)
      expect(json_response['message']).to eq("Failed to cancel auto stop because #{message}.")
    end
  end
end

RSpec.shared_examples 'avoids N+1 queries on environment detail page' do
  render_views

  before do
    create_deployment_with_associations(sequence: 0)
  end

  it 'avoids N+1 queries' do
    control = ActiveRecord::QueryRecorder.new { get :show, params: environment_params }

    create_deployment_with_associations(sequence: 1)
    create_deployment_with_associations(sequence: 2)

    expect { get :show, params: environment_params }.not_to exceed_query_limit(control.count).with_threshold(34)
  end
end
