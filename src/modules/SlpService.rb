##
#  Improved API for consuming SLP services in Yast
#
#  The main purpose of this module is to have a more developer friendly
#  API for searching and manipulating SLP services. It hides the complexity of
#  SLP protocol queries by concentrating the discovery call into a single method
#  call taking into account the service type along with its attributes.
#
#  Examples:
#
#    # A simple query for available ldap services:
#
#    Yast::SlpService.find('ldap') # return a service object or nil if none found
#    Yast::SlpService.all('ldap')  # return all discovered services in a collection
#
#    # A query for installation server service with scope and protocol parameters:
#
#    Yast::SlpService.all('install.suse', :scope=>'scope_name', :protocol=>'ftp')
#
#    # A similar query narrowing the results by criteria for service attributes:
#
#    Yast::SlpService.all('install.suse', :machine=>'x86_64')
#
#    # How to access the obtained service properties:
#
#    service = Yast::SlpService.find('ldap', :port=>389, :description=>'main')
#    service.name     # => 'ldap'
#    service.ip       # => '10.10.10.10'
#    service.port     # => 389
#    service.slp_type # => 'service:ldap'
#    service.slp_url  # => 'service:ldap://server.me:389'
#    service.protocol # => 'ldap'
#    service.host     # => 'server.me'
#    service.lifetime # => 65535
#    service.attributes.description # => 'Main LDAP server'
#
#    The matching of the attributes is case insensitive.
#
#    # How to get a list of available service types:
#
#    Yast::SlpService.types.each do |type|
#      puts type.name
#      puts type.protocol
#    end
#
#    The rule is: if the service name is equal to protocol name, don't pass the protocol
#    name as parameter to the search query (this is typical i.e. for ntp, ssh or ldap services).
##

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
        service = Service.new(service_name, slp_response, params)
        service = service.match(params)
        break if service
      end
      service
    end

    def all(service_name, params={})
      service_type = create_service_type(service_name, params[:protocol])
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

    def discover_available_slp_service_types
      SLP.FindSrvTypes('*', '')
    end

    class Service

      attr_reader :name, :ip, :host, :protocol, :port
      attr_reader :slp_type, :slp_url, :lifetime, :attributes

      def initialize(service_name, slp_data, params)
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

      def match(params)
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
