# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        module Limit
          class RateLimit < Chain::Base
            include Chain::Helpers

            def perform!
              # We exclude child-pipelines from the rate limit because they represent
              # sub-pipelines that would otherwise hit the rate limit due to having the
              # same scope (project, user, sha).
              #
              return if pipeline.parent_pipeline?

              if rate_limit_throttled?
                create_log_entry
                error(throttle_message) if enforce_throttle?
              end
            end

            def break?
              @pipeline.errors.any?
            end

            private

            def rate_limit_throttled?
              ::Gitlab::ApplicationRateLimiter.throttled?(
                :pipelines_create, scope: [project, current_user, command.sha]
              )
            end

            def create_log_entry
              Gitlab::AppJsonLogger.info(
                class: self.class.name,
                namespace_id: project.namespace_id,
                project_id: project.id,
                commit_sha: command.sha,
                current_user_id: current_user.id,
                subscription_plan: project.actual_plan_name,
                message: 'Activated pipeline creation rate limit'
              )
            end

            def throttle_message
              'Too many pipelines created in the last minute. Try again later.'
            end

            def enforce_throttle?
              ::Feature.enabled?(
                :ci_enforce_throttle_pipelines_creation,
                project)
            end
          end
        end
      end
    end
  end
end
