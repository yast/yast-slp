require 'resolv'
require 'ostruct'

module Yast
  Yast.import 'SLP'

  class SlpServiceClass < Module

    SCHEME = 'service'
    DELIMITER = ':'

    def find service_name, params={}
      service = nil
      service_type = [SCHEME, service_name, params[:protocol]].compact.join(DELIMITER)
      discover_service(service_type, params[:scope]).each do |slp_response|
        service = Service.new(service_name, slp_response, params)
        service = service.match(params)
        break if service
      end
      service
    end

    def all service_name, params={}
      service_type = [SCHEME, service_name, params[:protocol]].compact.join(DELIMITER)
      services = discover_service(service_type, params[:scope]).map do |slp_response|
        Service.new(service_name, slp_response, params).match(params)
      end
      services.compact
    end

    def types
      available_services = []
      discovered_services = discover_available_slp_service_types
      return available_services if discovered_services.empty?

      discovered_services.each do |slp_service_type|
        available_services << parse_slp_type(slp_service_type)
      end
      available_services
    end

    alias_method :keys, :types

    private

    def parse_slp_type service_type
      type_parts = service_type.split(DELIMITER)
      case type_parts.size
      when 2
        name = protocol = type_parts.last
      when 3
        name = type_parts[1]
        protocol = type_parts[2]
      else
        raise "Incorrect slp service type: #{service.inspect}"
      end
      OpenStruct.new :name => name, :protocol => protocol
    end

    def discover_service service_name, scope=''
      SLP.FindSrvs(service_name, scope)
    end

    def discover_available_slp_service_types
      SLP.FindSrvTypes('*', '')
    end

    class Service

      attr_reader :name, :ip, :host, :protocol, :port
      attr_reader :slp_type, :slp_url, :lifetime, :attributes

      def initialize service_name, slp_data, params
        @name = service_name
        @ip = slp_data['ip']
        @port = slp_data['pcPort']
        @slp_type = slp_data['pcSrvType']
        @slp_url = slp_data['srvurl']
        @protocol = params[:protocol] || slp_type.split(DELIMITER).last
        @host = resolve_host
        @lifetime = slp_data['lifetime']
        @attributes = OpenStruct.new(SLP.GetUnicastAttrMap(slp_url, ip))
      end

      def match params
        matches = []
        params.each do |key, value|
          if respond_to?(key)
            result = send(key).to_s
            matches << result.match(/#{value}/i)
          elsif attributes.respond_to?(key)
            result = attributes.send(key).to_s
            matches << result.match(/#{value}/i)
          else
            return
          end
        end
        matches.all? ? self : nil
      end

      private

      def resolve_host
        host = DnsCache.find(ip)
        return host if host

        host = Resolv.getname(ip)
        DnsCache.update(ip => host)
        host
      end

      module DnsCache
        def self.entries
          @entries ||= {}
        end

        def self.find ip_address
          entries[ip_address]
        end

        def self.update entry
          entries.merge!(entry)
        end
      end
    end
  end
  SlpService = SlpServiceClass.new
end
