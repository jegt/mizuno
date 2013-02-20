
#
# Wraps a Rack application in a Jetty handler.
#
module Mizuno
#  java_import 'org.eclipse.jetty.websocket.WebSocketHandler'
#  java_import 'org.eclipse.jetty.websocket.WebSocket'

    class WebSocket
        include Java::OrgEclipseJettyWebsocket::WebSocket::OnTextMessage

        def initialize(request, protocol, broker)
            @request = request
            @protocol = protocol
            @broker = broker
            super()
        end

        java_signature %{@Override void onOpen(Connection connection)}
        def onOpen(connection)
          @connection = connection
          @handler = @broker.add_socket(self)
          @handler.on_open(self)
        end

        java_signature %{@Override void onMessage(String data)}
        def onMessage(data)
          @handler.on_message(data)
        end

        java_signature %{@Override void onClose(int closeCode, String message)}
        def onClose(closeCode, message)
          @handler.on_close(code, message)
          @broker.remove_socket(self)
        end

        def send(data)
          @connection.sendMessage(data)
        end

        def open?
          @connection.isOpen()
        end

    end
end
