require 'socket'
require 'timeout'

module Puppet
  module Util
    class EsInstanceValidator
      attr_reader :instance_server
      attr_reader :instance_port

      def initialize(instance_name)
        @instance_name = instance_name

        IO.popen("ps aux | grep elasticsearch-#{instance_name} | head -1 | awk '{print $2}'") { |pipe| $instance_pid = pipe.read.chomp }
        IO.popen("netstat -tlnp | grep #{$instance_pid} | head -1 | sed -r \"s/.*\s(([0-9]{1,3}\.){3}[0-9]{1,3}):([0-9]+)\s.*/\\1/\"") { |pipe| $listening_ip = pipe.read.chomp }
        IO.popen("netstat -tlnp | grep #{$instance_pid} | head -1 | sed -r \"s/.*\s(([0-9]{1,3}\.){3}[0-9]{1,3}):([0-9]+)\s.*/\\3/\"") { |pipe| @instance_port = pipe.read.chomp.to_i }

        if $listening_ip.eql? '0.0.0.0'
          @instance_server = '127.0.0.1'
        else
          @instance_server = $listening_ip
        end
      end

      # Utility method; attempts to make an https connection to the Elasticsearch instance.
      # This is abstracted out into a method so that it can be called multiple times
      # for retry attempts.
      #
      # @return true if the connection is successful, false otherwise.
      def attempt_connection
        Timeout::timeout(Puppet[:configtimeout]) do
          begin
            TCPSocket.new(@instance_server, @instance_port).close
            true
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
            Puppet.debug "Unable to connect to Elasticsearch instance #{@instance_name} on #{@instance_server}:#{@instance_port}: #{e.message}"
            false
          end
        end
      rescue Timeout::Error
        false
      end
    end
  end
end

