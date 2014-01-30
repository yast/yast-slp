#!/usr/bin/env rspec
#
ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import 'SlpService'

describe Yast::SlpService do
  before do
    Yast::SlpService.stub(:discover_service).and_return(
      [
        {
          'ip'        => '10.100.2.16',
          'pcFamily'  => 'IP',
          'pcHost'    => '10.100.2.16',
          'pcPort'    => 0,
          'pcSrvPart' => '/install/SLP/SLE-10-SP4-SDK-RC3/x86_64/DVD1',
          'pcSrvType' => 'service:install.suse.http',
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
        "service:smtp",
        "service:install.suse:http",
        "service:ntp",
        "service:ldap"
      ]
    )

    ::Resolv.stub(:getname).and_return('fallback.suse.cz')
  end

  describe "#find" do
    it "returns the first discovered service that matches the service name and params" do
      service = Yast::SlpService.find('install.suse', :protocol=>'http', :machine=>'x86_64')
      expect(service.name).to eq('install.suse')
      expect(service.ip).to eq('10.100.2.16')
      expect(service.host).to eq('fallback.suse.cz')
      expect(service.protocol).to eq('http')
      expect(service.port).to eq(0)
      expect(service.lifetime).to eq(65535)
      expect(service).to respond_to(:attributes)
      expect(service.attributes).to respond_to(:machine)
      expect(service.attributes.machine).to eq('x86_64')
      expect(service.attributes).to respond_to(:description)
      expect(service.attributes.description).to eq('SLE_10_SP4_SDK')
    end
  end

  describe "#all" do
    it "returns a collection of services" do
      services = Yast::SlpService.all('install.suse')
      expect(services.size).to eq(1)
      expect(services.first).to be_a(Yast::SlpServiceClass::Service)
    end
  end

  describe "#types" do
    it "returns a collection of discovered services" do
      service_types = Yast::SlpService.types
      expect(service_types).to respond_to(:each)
      type = service_types.find {|t| t.name == 'install.suse' }
      expect(type).not_to eq(nil)
      expect(type.name).to eq('install.suse')
      expect(type.protocol).to eq('http')
    end
  end
end
