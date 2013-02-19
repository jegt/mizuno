require 'mizuno/web_socket'

module Mizuno

    class WebSocketHandler < Java::OrgEclipseJettyWebsocket::WebSocketHandler

        def initialize(server)
            @server = server
            super()
        end

        java_signature %{@Override org.eclipse.jetty.websocket.WebSocket doWebSocketConnect(HttpServletRequest request,String protocol)}
        def doWebSocketConnect(request, protocol)
          return WebSocket.new(request, protocol, WebSocketBroker.broker)
        end

    end

end
