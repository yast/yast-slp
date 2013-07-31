# encoding: utf-8

module Yast
  class SlpClient < Client
    def main

      Builtins.y2milestone(
        "slp: %1",
        SCR.Read(
          path(".slp.findsrvs"),
          { "pcServiceType" => "CIM-Object-Manager" }
        )
      )

      Builtins.y2milestone(
        "slp: %1",
        SCR.Read(
          path(".slp.findattrs"),
          {
            "pcURLOrServiceType" => "service:CIM-Object-Manager:https://D116.suse.de:5989/cimom"
          }
        )
      )

      Builtins.y2milestone(
        "slp: %1",
        SCR.Read(path(".slp.findsrvtypes"), { "pcNamingAuthority" => "*" })
      )

      Builtins.y2milestone(
        "reg: %1",
        SCR.Execute(path(".slp.reg"), "service:TEST:http://192.168.1.1/blah")
      )

      nil
    end
  end
end

Yast::SlpClient.new.main
