# frozen_string_literal: true

class Import::BitbucketController < Import::BaseController
  extend ::Gitlab::Utils::Override

  include ActionView::Helpers::SanitizeHelper

  before_action :verify_bitbucket_import_enabled
  before_action :bitbucket_auth, except: :callback

  rescue_from OAuth2::Error, with: :bitbucket_unauthorized
  rescue_from Bitbucket::Error::Unauthorized, with: :bitbucket_unauthorized

  def callback
    auth_state = session[:bitbucket_auth_state]
    session[:bitbucket_auth_state] = nil

    if auth_state.blank? || !ActiveSupport::SecurityUtils.secure_compare(auth_state, params[:state])
      go_to_bitbucket_for_permissions
    else
      response = oauth_client.auth_code.get_token(params[:code], redirect_uri: users_import_bitbucket_callback_url)

      session[:bitbucket_token]         = response.token
      session[:bitbucket_expires_at]    = response.expires_at
      session[:bitbucket_expires_in]    = response.expires_in
      session[:bitbucket_refresh_token] = response.refresh_token

      redirect_to status_import_bitbucket_url
    end
  end

  # We need to re-expose controller's internal method 'status' as action.
  # rubocop:disable Lint/UselessMethodDefinition
  def status
    super
  end
  # rubocop:enable Lint/UselessMethodDefinition

  def create
    bitbucket_client = Bitbucket::Client.new(credentials)

    repo_id = params[:repo_id].to_s
    name = repo_id.gsub('___', '/')
    repo = bitbucket_client.repo(name)
    project_name = params[:new_name].presence || repo.name

    repo_owner = repo.owner
    repo_owner = current_user.username if repo_owner == bitbucket_client.user.username
    namespace_path = params[:new_namespace].presence || repo_owner
    target_namespace = find_or_create_namespace(namespace_path, current_user)

    if current_user.can?(:create_projects, target_namespace)
      # The token in a session can be expired, we need to get most recent one because
      # Bitbucket::Connection class refreshes it.
      session[:bitbucket_token] = bitbucket_client.connection.token

      project = Gitlab::BitbucketImport::ProjectCreator.new(repo, project_name, target_namespace, current_user, credentials).execute

      if project.persisted?
        render json: ProjectSerializer.new.represent(project, serializer: :import)
      else
        render json: { errors: project_save_error(project) }, status: :unprocessable_entity
      end
    else
      render json: { errors: _('This namespace has already been taken! Please choose another one.') }, status: :unprocessable_entity
    end
  end

  protected

  override :importable_repos
  def importable_repos
    bitbucket_repos.filter { |repo| repo.valid? }
  end

  override :incompatible_repos
  def incompatible_repos
    bitbucket_repos.reject { |repo| repo.valid? }
  end

  override :provider_name
  def provider_name
    :bitbucket
  end

  override :provider_url
  def provider_url
    provider.url
  end

  private

  def oauth_client
    @oauth_client ||= OAuth2::Client.new(provider.app_id, provider.app_secret, options)
  end

  def provider
    Gitlab::Auth::OAuth::Provider.config_for('bitbucket')
  end

  def client
    @client ||= Bitbucket::Client.new(credentials)
  end

  def bitbucket_repos
    @bitbucket_repos ||= client.repos(filter: sanitized_filter_param).to_a
  end

  def options
    OmniAuth::Strategies::Bitbucket.default_options[:client_options].deep_symbolize_keys
  end

  def verify_bitbucket_import_enabled
    render_404 unless bitbucket_import_enabled?
  end

  def bitbucket_auth
    go_to_bitbucket_for_permissions if session[:bitbucket_token].blank?
  end

  def go_to_bitbucket_for_permissions
    state = SecureRandom.base64(64)
    session[:bitbucket_auth_state] = state
    redirect_to oauth_client.auth_code.authorize_url(redirect_uri: users_import_bitbucket_callback_url, state: state)
  end

  def bitbucket_unauthorized(exception)
    log_exception(exception)

    go_to_bitbucket_for_permissions
  end

  def credentials
    {
      token: session[:bitbucket_token],
      expires_at: session[:bitbucket_expires_at],
      expires_in: session[:bitbucket_expires_in],
      refresh_token: session[:bitbucket_refresh_token]
    }
  end
end
