
module Mizuno

  class WebSocketBroker

    def self.broker
      @@broker ||= WebSocketBroker.new
    end

    def initialize()
      @sockets = Array.new
    end

    def sockets
      @sockets
    end

    def add_socket(socket)
      @sockets << socket
      if @klass
        return @klass.new
      elsif @handler
        return @handler
      else
        raise "No handler set!"
      end
    end

    def remove_socket(socket)
      @sockets.delete(socket)
    end

    def set_handler_class(klass)
      @klass = klass
    end

    def set_handler(handler)
      @handler = handler
    end

  end

end
