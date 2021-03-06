# FIXME: mizuno/http_server needs to still work, but we will throw out a
# deprecation notice and remove it in later versions.

require 'rack'
require 'rack/rewindable_input'
require 'mizuno'
Mizuno.require_jars(%w(jetty-continuation jetty-http jetty-io jetty-jmx
    jetty-security jetty-server jetty-util servlet-api
    rewindable-input-stream jetty-websocket))
require 'mizuno/version'
require 'mizuno/rack/chunked'
require 'mizuno/rack_handler'
require 'mizuno/logger'
require 'mizuno/reloader'
require 'mizuno/web_socket_handler'

module Mizuno
    class Server
        java_import 'org.eclipse.jetty.server.nio.SelectChannelConnector'
        java_import 'org.eclipse.jetty.util.thread.QueuedThreadPool'
        java_import 'org.jruby.rack.servlet.RewindableInputStream'

        attr_accessor :logger

        @lock ||= Mutex.new

        def Server.run(app, options = {})
            @lock.synchronize do
                return if @server
                @server = new
                @server.run(app, options)
            end
        end

        def Server.stop
            @lock.synchronize do 
                return unless @server
                @server.stop
                @server = nil
            end
        end

        def Server.logger
            Logger.logger
        end

        #
        # Start up an instance of Jetty, running a Rack application.
        # Options can be any of the follwing, and are not
        # case-sensitive:
        #
        # :host::
        #     String specifying the IP address to bind to; defaults 
        #     to 0.0.0.0.
        #
        # :port::
        #     String or integer with the port to bind to; defaults 
        #     to 9292.
        #
        def run(app, options = {})
            # Symbolize and downcase keys.
            @options = options = Hash[options.map { |k, v| 
                [ k.to_s.downcase.to_sym, v ] }]
            options[:quiet] ||= true if options[:embedded]

            # The Jetty server
            Logger.configure(options)
            @logger = Logger.logger
            @server = Java.org.eclipse.jetty.server.Server.new
            @server.setSendServerVersion(false)

            # Thread pool
            threads = options[:threads] || 50
            thread_pool = QueuedThreadPool.new
            thread_pool.min_threads = [ threads.to_i / 10, 5 ].max
            thread_pool.max_threads = [ threads.to_i, 10 ].max
            @server.set_thread_pool(thread_pool)

            # Connector
            connector = SelectChannelConnector.new
            connector.setPort(options[:port].to_i)
            connector.setHost(options[:host])
            @server.addConnector(connector)

            # Switch to a different user or group if we were asked to.
            Runner.setgid(options) if options[:group]
            Runner.setuid(options) if options[:user]

            # Optionally wrap with Mizuno::Reloader.
            threshold = (ENV['RACK_ENV'] == 'production' ? 10 : 1)
            app = Mizuno::Reloader.new(app, threshold) \
                if options[:reloadable]

            # The servlet itself.
            rack_handler = RackHandler.new(self)
            rack_handler.rackup(app)

            # Optionally enable websocket support
            if(options[:websocket])
              web_socket_handler = WebSocketHandler.new(self)
              web_socket_handler.set_handler(rack_handler)
              handler = web_socket_handler
            else
              handler = rack_handler
            end

            # Add the context to the server and start.
            @server.set_handler(handler)
            @server.start
            $stderr.printf("%s listening on %s:%s\n", version,
                connector.host, connector.port) unless options[:quiet]

            # If we're embedded, we're done.
            return if options[:embedded]

            # Stop the server when we get The Signal.
            trap("SIGINT") { @server.stop and exit }

            # Join with the server thread, so that currently open file
            # descriptors don't get closed by accident.
            # http://www.ruby-forum.com/topic/209252
            @server.join
        end

        #
        # Shuts down an embedded Jetty instance.
        #
        def stop
            return unless @server
            $stderr.print "Stopping Jetty..." unless @options[:quiet]
            @server.stop
            $stderr.puts "done." unless @options[:quiet]
        end

        #
        # Returns the full version string.
        #
        def version
            "Mizuno #{Mizuno::VERSION} (Jetty #{Java.org.eclipse.jetty.server.Server.getVersion})"
        end

        #
        # Wraps the Java InputStream for the level of Rack compliance
        # desired.
        #
        def rewindable(request)
            input = request.getInputStream

            @options[:rewindable] ?
                Rack::RewindableInput.new(input.to_io.binmode) :
                RewindableInputStream.new(input).to_io.binmode
        end
    end
end
