# frozen_string_literal: true

require 'webrick'
require 'prometheus/client/rack/exporter'

module Gitlab
  module Metrics
    module Exporter
      class BaseExporter < Daemon
        attr_reader :server

        # @param settings [Hash] SettingsLogic hash containing the `*_exporter` config
        # @param log_enabled [Boolean] whether to log HTTP requests
        # @param log_file [String] path to where the server log should be located
        # @param gc_requests [Boolean] whether to run a major GC after each scraper request
        def initialize(settings, log_enabled:, log_file:, gc_requests: false, **options)
          super(**options)

          @settings = settings
          @gc_requests = gc_requests

          # log_enabled does not exist for all exporters
          log_sink = log_enabled ? File.join(Rails.root, 'log', log_file) : File::NULL
          @logger = WEBrick::Log.new(log_sink)
          @logger.time_format = "[%Y-%m-%dT%H:%M:%S.%L%z]"
        end

        def enabled?
          settings.enabled
        end

        private

        attr_reader :settings, :logger

        def start_working
          access_log = [
            [logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT]
          ]

          @server = ::WEBrick::HTTPServer.new(
            Port: settings.port, BindAddress: settings.address,
            Logger: logger, AccessLog: access_log
          )
          server.mount '/', Rack::Handler::WEBrick, rack_app

          true
        rescue StandardError => e
          logger.error(e)
          false
        end

        def run_thread
          server&.start
        rescue IOError
          # ignore forcibily closed servers
        end

        def stop_working
          if server
            # we close sockets if thread is not longer running
            # this happens, when the process forks
            if thread.alive?
              server.shutdown
            else
              server.listeners.each(&:close)
            end
          end

          @server = nil
        end

        def rack_app
          pid = thread_name
          gc_requests = @gc_requests

          Rack::Builder.app do
            use Rack::Deflater
            use Gitlab::Metrics::Exporter::MetricsMiddleware, pid
            use Gitlab::Metrics::Exporter::GcRequestMiddleware if gc_requests
            use ::Prometheus::Client::Rack::Exporter if ::Gitlab::Metrics.metrics_folder_present?
            run -> (env) { [404, {}, ['']] }
          end
        end
      end
    end
  end
end
