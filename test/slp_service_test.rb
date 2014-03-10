#!/usr/bin/env rspec
#
ENV['Y2DIR'] = File.expand_path('../../src', __FILE__)

require 'yast'

Yast.import 'SlpService'

describe Yast::SlpService do
  before do
    @service = double('service',
                      :name=>'install.suse', :ip=>'10.100.2.16',
                      :host => 'fallback.suse.cz', :protocol => 'http',
                      :lifetime => 65535, :port => 0)

    @attributes = double('attributes', :machine=>'x86_64', :description=>'SLE_10_SP4_SDK')


    Yast::SlpService.stub(:discover_service).and_return(
      [
        {
          'ip'        => '10.100.2.16',
          'pcFamily'  => 'IP',
          'pcHost'    => '10.100.2.16',
          'pcPort'    => 0,
          'pcSrvPart' => '/install/SLP/SLE-10-SP4-SDK-RC3/x86_64/DVD1',
          'pcSrvType' => 'service:install.suse:http',
          'srvurl'    => 'service:install.suse:http://10.100.2.16/install/SLP/SLE-10-SP4-SDK-RC3/x86_64/DVD1',
          'lifetime'  => 65535
        }
      ]
    )

    Yast::SLP.stub(:GetUnicastAttrMap).and_return(
      {
        'machine' => 'x86_64',
        'description' => 'SLE_10_SP4_SDK'
      }
    )

    Yast::SLP.stub(:FindSrvTypes).and_return(
      [
        'service:smtp',
        'service:install.suse:http',
        'service:ntp',
        'service:ldap'
      ]
    )

    ::Resolv.stub(:getname).and_return('fallback.suse.cz')
  end

  describe '#find' do
    it 'returns the first discovered service that matches the service name and params' do
      service = Yast::SlpService.find('install.suse', :machine=>'x86_64')
      expect(service.name).to eq(@service.name)
      expect(service.ip).to eq(@service.ip)
      expect(service.host).to eq(@service.host)
      expect(service.protocol).to eq(@service.protocol)
      expect(service.port).to eq(@service.port)
      expect(service.lifetime).to eq(@service.lifetime)
      expect(service).to respond_to(:attributes)
      expect(service.attributes).to respond_to(:machine)
      expect(service.attributes.machine).to eq(@attributes.machine)
      expect(service.attributes).to respond_to(:description)
      expect(service.attributes.description).to eq(@attributes.description)
    end

    it 'returns nil if no matching service found' do
      service = Yast::SlpService.find('install.suse', :machine=>'Dell')
      expect(service).to eq(nil)
    end

    it "returns discovered service without host name if IP address resolution fails" do
      ip_address = '100.100.100.100'
      Yast::SlpService.stub(:discover_service).and_return(
        [
          {
            'ip'        => ip_address,
            'pcFamily'  => 'IP',
            'pcHost'    => ip_address,
            'pcPort'    => 0,
            'pcSrvType' => 'service:install.suse:http',
            'srvurl'    => 'service:install.suse:http://10.100.2.16/install/SLP/SLE-10-SP4-SDK-RC3/x86_64/DVD1',
            'lifetime'  => 65535
          }
        ]
      )
      ::Resolv.stub(:getname).and_raise(Resolv::ResolvError)
      service = Yast::SlpService.find('install.suse')
      expect(service.ip).to eq(ip_address)
      expect(service.host).to be_nil
    end
  end

  describe '#all' do
    it 'returns a collection of services' do
      services = Yast::SlpService.all('install.suse')
      expect(services.size).to eq(1)
      service = services.first
      expect(service).to be_a(Yast::SlpServiceClass::Service)
      expect(service.name).to eq(@service.name)
      expect(service.ip).to eq(@service.ip)
      expect(service.host).to eq(@service.host)
      expect(service.protocol).to eq(@service.protocol)
    end
  end

  describe '#types' do
    before do
      @type = double('type', :name => 'install.suse', :protocol => 'http')
    end

    it 'returns a collection of discovered service types' do
      service_types = Yast::SlpService.types
      expect(service_types).to respond_to(:each)
      type = service_types.find {|t| t.name == @type.name }
      expect(type).not_to eq(nil)
      expect(type.protocol).to eq(@type.protocol)
    end
  end
end
