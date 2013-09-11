# encoding: utf-8

# File:	modules/SLP.ycp
# Package:	SLP Browser / Agent
# Summary:	Access to SLP Agent functions
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class SLPClass < Module
    def main
      @Regd = "/etc/slp.reg.d"
    end

    # Issue the query for services
    # @param [String] pcServiceType The Service Type String, including authority string if
    # any, for the request, such as can be discovered using  SLPSrvTypes().
    # This could be, for example "service:printer:lpr" or "service:nfs".
    # @param [String] pcScopeList comma separated  list of scope names to search for
    # service types.
    # @return [Array<Hash>] List of Services
    def FindSrvs(pcServiceType, pcScopeList)
      _Srvs = Convert.convert(
        SCR.Read(
          path(".slp.findsrvs"),
          { "pcServiceType" => pcServiceType, "pcScopeList" => pcScopeList }
        ),
        :from => "any",
        :to   => "list <map>"
      )
      Builtins.y2debug("FindSrvs: %1", _Srvs)
      deep_copy(_Srvs)
    end

    # Issues an SLP service type request for service types in the scopes
    # indicated by the pcScopeList.
    #
    # If the naming authority is "*", then
    # results are returned for all naming authorities.  If the naming
    # authority is the empty string, i.e.  "", then the default naming
    # authority, "IANA", is used.
    #
    # @param [String] pcNamingAuthority The naming authority to search.
    # @param [String] pcScopeList  comma separated  list of scope names to search for
    # service types.
    # @return [Array<String>] Service Types
    def FindSrvTypes(pcNamingAuthority, pcScopeList)
      _Types = Convert.convert(
        SCR.Read(
          path(".slp.findsrvtypes"),
          {
            "pcNamingAuthority" => pcNamingAuthority,
            "pcScopeList"       => pcScopeList
          }
        ),
        :from => "any",
        :to   => "list <string>"
      )
      deep_copy(_Types)
    end



    # Find attributes of a service
    # @param [String] pcURLOrServiceType service url or type
    # @return [Array<String>] attributes
    def FindAttrs(pcURLOrServiceType)
      _Attrs = Convert.convert(
        SCR.Read(
          path(".slp.findattrs"),
          { "pcURLOrServiceType" => pcURLOrServiceType }
        ),
        :from => "any",
        :to   => "list <string>"
      )
      deep_copy(_Attrs)
    end


    # Find attributes of a service using a unicast query
    # @param [String] pcURLOrServiceType service url or type
    # @param [String] ip IP address of the server
    # @return [Array<String>] attributes
    def UnicastFindAttrs(pcURLOrServiceType, ip)
      return FindAttrs(pcURLOrServiceType) if ip == ""

      _Attrs = Convert.convert(
        SCR.Read(
          path(".slp.unicastfindattrs"),
          { "pcURLOrServiceType" => pcURLOrServiceType, "ip-address" => ip }
        ),
        :from => "any",
        :to   => "list <string>"
      )
      deep_copy(_Attrs)
    end


    # Find attributes (using unicast query) of a service and return a map
    # @param [String] pcURLOrServiceType service url or type
    # @param [String] ip IP address of the server
    # @return [Hash{String => String}] attributes
    def GetUnicastAttrMap(pcURLOrServiceType, ip)
      _Attrs = UnicastFindAttrs(pcURLOrServiceType, ip)
      Builtins.listmap(_Attrs) do |a|
        s = Builtins.substring(a, 1, Ops.subtract(Builtins.size(a), 2))
        aa = Builtins.splitstring(s, "=")
        { Ops.get_string(aa, 0, "empty") => Ops.get_string(aa, 1, "empty") }
      end
    end

    # Find attributes of a service and return a map
    # @param [String] pcURLOrServiceType service url or type
    # @return [Hash{String => String}] attributes
    def GetAttrMap(pcURLOrServiceType)
      _Attrs = FindAttrs(pcURLOrServiceType)
      att = Builtins.listmap(_Attrs) do |a|
        s = Builtins.substring(a, 1, Ops.subtract(Builtins.size(a), 2))
        aa = Builtins.splitstring(s, "=")
        { Ops.get_string(aa, 0, "empty") => Ops.get_string(aa, 1, "empty") }
      end
      deep_copy(att)
    end

    # Register service with SLP
    # @param [String] service Service to be registered
    # @return [Boolean] True on success
    def Reg(service)
      ret = Convert.to_boolean(SCR.Execute(path(".slp.reg"), service))
      ret
    end

    # Deregister service with SLP
    # @param [String] service Service to be deregistered
    # @return [Boolean] True on success
    def DeReg(service)
      ret = Convert.to_boolean(SCR.Execute(path(".slp.dereg"), service))
      ret
    end

    # Register service with SLP using a reg file
    # @param [String] service The service to be registered
    # @param [Hash{String => String}] attr Attributes
    # @param [String] regfile Reg File
    # @return [Boolean] True on Success
    def RegFile(service, attr, regfile)
      attr = deep_copy(attr)
      slp = []
      slp = Builtins.add(slp, service)
      Builtins.foreach(attr) do |k, v|
        slp = Builtins.add(
          slp,
          Builtins.sformat("%1=%2", Builtins.tolower(k), v)
        )
      end

      all = Builtins.mergestring(slp, "\n")
      SCR.Execute(path(".target.mkdir"), @Regd)
      ret = SCR.Write(
        path(".target.string"),
        Builtins.sformat("%1/%2", @Regd, regfile),
        all
      )
      ret
    end

    # De-Register service with SLP by removing the reg file
    # @param [String] regfile The service to be deregistered
    # @return [Boolean] True on success
    def DeRegFile(regfile)
      ret = Convert.to_boolean(SCR.Execute(path(".target.remove"), regfile))
      ret
    end
    # Match Srv Type and return all data
    # @param [String] match match string
    # @return [Array<Hash>] list of services matching with all relevant data
    def MatchType(match)
      t = FindSrvTypes("*", "")
      ret = []
      Builtins.foreach(t) do |type|
        if Builtins.regexpmatch(type, match)
          matched = FindSrvs(type, "")
          ret = Convert.convert(
            Builtins.union(ret, Builtins.maplist(matched) do |m|
              Ops.set(m, "attr", GetAttrMap(Ops.get_string(m, "srvurl", "")))
              deep_copy(m)
            end),
            :from => "list",
            :to   => "list <map>"
          )
        end
      end
      deep_copy(ret)
    end

    publish :function => :FindSrvs, :type => "list <map> (string, string)"
    publish :function => :FindSrvTypes, :type => "list <string> (string, string)"
    publish :function => :FindAttrs, :type => "list <string> (string)"
    publish :function => :UnicastFindAttrs, :type => "list <string> (string, string)"
    publish :function => :GetUnicastAttrMap, :type => "map <string, string> (string, string)"
    publish :function => :GetAttrMap, :type => "map <string, string> (string)"
    publish :function => :Reg, :type => "boolean (string)"
    publish :function => :DeReg, :type => "boolean (string)"
    publish :function => :RegFile, :type => "boolean (string, map <string, string>, string)"
    publish :function => :DeRegFile, :type => "boolean (string)"
    publish :function => :MatchType, :type => "list <map> (string)"
  end

  SLP = SLPClass.new
  SLP.main
end
