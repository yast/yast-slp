# = Improved API for consuming SLP services in Yast
# The main purpose of this module is to have a more developer friendly
# API for searching and manipulating SLP services. It hides the complexity of
# SLP protocol queries by concentrating the discovery call into a single method
# call taking into account the service type along with its attributes.
#
# == A simple query for available ldap services
#
# Example:
#
#   Yast::SlpService.find('ldap') # return a service object or nil if none found
#   Yast::SlpService.all('ldap')  # return all discovered services in a collection
#
# == A query for installation server service with scope and protocol parameters
#
# Example:
#
#   Yast::SlpService.all('install.suse', :scope=>'some-scope', :protocol=>'ftp')
#
# == A similar query narrowing the results by criteria for service attributes
#
# Example:
#
#   Yast::SlpService.all('install.suse', :machine=>'x86_64')
#
# == How to access the obtained service properties
#
# Example:
#
#   service = Yast::SlpService.find('ldap', :port=>389, :description=>'main')
#   service.name     # => 'ldap'
#   service.ip       # => '10.10.10.10'
#   service.port     # => 389
#   service.slp_type # => 'service:ldap'
#   service.slp_url  # => 'service:ldap://server.me:389'
#   service.protocol # => 'ldap'
#   service.host     # => 'server.me'
#   service.lifetime # => 65535
#   service.attributes.description # => 'Main LDAP server'
#
# The matching of the attributes is case insensitive.
#
# == How to get a list of available service types:
#
#   Yast::SlpService.types.each do |type|
#     puts type.name
#     puts type.protocol
#   end
#
# The rule is: if the service name is equal to protocol name, don't pass the protocol
# name as parameter to the search query (this is typical i.e. for ntp, ssh or ldap services).

require 'resolv'
require 'ostruct'

module Yast
  Yast.import 'SLP'

  class SlpServiceClass < Module

    SCHEME = 'service'
    DELIMITER = ':'

    def find(service_name, params={})
      service = nil
      service_type = create_service_type(service_name, params[:protocol])
      discover_service(service_type, params[:scope]).each do |slp_response|
        service = Service.create(params.merge(:name=>service_name, :data=>slp_response))
        break if service
      end
      service
    end

    def all(service_name, params={})
      service_type = create_service_type(service_name, params[:protocol])
      services = discover_service(service_type, params[:scope]).map do |slp_response|
        Service.create(params.merge(:name=>service_name, :data=>slp_response))
      end
      services.compact
    end

    def types
      available_services = []
      discovered_services = discover_service_types
      return available_services if discovered_services.empty?

      discovered_services.each do |slp_service_type|
        available_services << parse_slp_type(slp_service_type)
      end
      available_services
    end

    private

    def create_service_type(service_name, protocol)
      [SCHEME, service_name, protocol].compact.join(DELIMITER)
    end

    def parse_slp_type(service_type)
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

    def discover_service(service_name, scope='')
      SLP.FindSrvs(service_name, scope)
    end

    def discover_service_types
      SLP.FindSrvTypes('*', '')
    end

    class Service

      def self.create params
        new(params).verify!
      end

      attr_reader :name, :ip, :host, :protocol, :port, :params
      attr_reader :slp_type, :slp_url, :lifetime, :attributes

      def initialize(params)
        @name = params.delete(:name)
        slp_data = params.delete(:data)
        @ip = slp_data['ip']
        @port = slp_data['pcPort']
        @slp_type = slp_data['pcSrvType']
        @slp_url = slp_data['srvurl']
        @protocol = params.delete(:protocol) || slp_type.split(DELIMITER).last
        @host = DnsCache.resolve(ip)
        @lifetime = slp_data['lifetime']
        @attributes = OpenStruct.new(SLP.GetUnicastAttrMap(slp_url, ip))
        @params = params
      end

      def verify!
        match = params.all? do |key, value|
          if respond_to?(key)
            result = send(key).to_s
            result.match(/#{value}/i)
          elsif attributes.respond_to?(key)
            result = attributes.send(key).to_s
            result.match(/#{value}/i)
          else
            false
          end
        end
        match ? self : nil
      end
    end

    module DnsCache
      def self.resolve(ip_address)
        host = find(ip_address)
        return host if host

        host = Resolv.getname(ip_address)
        update(ip_address => host)
        host
      end

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
  SlpService = SlpServiceClass.new
end
