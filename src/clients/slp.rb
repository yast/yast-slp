# encoding: utf-8

# File:	clients/slp.ycp
# Package:	SLP
# Summary:	SLP Browser
# Authors:	Anas Nashif <nashif@suse.de>
#
# $Id$
#
# Browse SLP services
module Yast
  class SlpClient < Client
    def main
      Yast.import "UI"
      Yast.import "SLP"
      textdomain "slp"
      Yast.import "Wizard"
      Yast.import "Label"


      # list<map> response = SLP::FindSrvs("CIM-Object-Manager");
      @tableItems = []
      @treeItems = []

      @contents = Top(
        VBox(
          Table(
            Id(:table),
            Opt(:notify, :immediate),
            Header(_("Type"), _("URL"), _("Lifetime")),
            @tableItems
          ),
          RichText(Id(:attr), "")
        )
      )

      @typeResponse = SLP.FindSrvTypes("*", "")

      @title = _("SLP Browser")
      Wizard.CreateTreeDialog
      Wizard.SetDesktopTitleAndIcon("slp")
      @Tree = fillTree(@typeResponse)
      Builtins.y2debug("Tree=%1", @Tree)
      Wizard.CreateTree(@Tree, _("Service Types"))

      @help = Builtins.dgettext("base", "No help available")
      Wizard.SetContentsButtons(
        @title,
        @contents,
        @help,
        Label.BackButton,
        Label.FinishButton
      )

      Wizard.HideAbortButton
      Wizard.DisableBackButton



      @input = nil
      @cache = {}
      @attrcache = {}
      begin
        @srvtype = ""
        @srv = ""
        @event = UI.WaitForEvent
        @input = Ops.get(@event, "ID")
        if @input == :wizardTree
          @input = UI.QueryWidget(Id(:wizardTree), :CurrentItem)
        end

        Builtins.y2debug("input: %1", @input)
        if Ops.is_string?(@input)
          @srvtype = Wizard.QueryTreeItem
        elsif @input == :table
          @srv = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
        end
        Builtins.y2debug("srvtype: %1", @srvtype)
        Builtins.y2debug("srv: %1", @srv)
        @srvsResponse = []
        if Builtins.haskey(@cache, @srvtype)
          @srvsResponse = Ops.get_list(@cache, @srvtype, [])
        else
          @srvsResponse = SLP.FindSrvs(@srvtype, "")
          Ops.set(@cache, @srvtype, @srvsResponse)
        end
        @tableItems = fillTable(@srvsResponse)

        @attr = []
        @sum = ""

        Builtins.foreach(@srvsResponse) do |s|
          srvurl = Ops.get_string(s, "srvurl", "")
          if Builtins.haskey(@attrcache, srvurl)
            @attr = Ops.get_list(@attrcache, srvurl, [])
          else
            Builtins.y2debug("s: %1", s)
            @attr = SLP.FindAttrs(srvurl)
            Builtins.y2debug("attr: %1", @attr)
            Ops.set(@attrcache, srvurl, @attr)
          end
        end

        if Ops.is_string?(@input)
          UI.ChangeWidget(Id(:table), :Items, @tableItems)
          @srv = Ops.get_string(@srvsResponse, [0, "srvurl"], "xxx")
          @sum = SLP.AttrSummary(Ops.get_list(@attrcache, @srv, []))
          UI.ChangeWidget(Id(:attr), :Value, @sum)
        elsif @input == :table
          @sum = SLP.AttrSummary(Ops.get_list(@attrcache, @srv, []))
          UI.ChangeWidget(Id(:attr), :Value, @sum)
        end
      end until @input == :next || @input == :abort || @input == :cancel

      UI.CloseDialog
      deep_copy(@input) 
      # EOF
    end

    def createTableItem(srv)
      srv = deep_copy(srv)
      tabitem = Item()

      srvurl = Ops.get_string(srv, "srvurl", "")

      tabitem = Item(
        Id(srvurl),
        Builtins.substring(Ops.get_string(srv, "pcSrvType", ""), 8),
        Builtins.substring(Ops.get_string(srv, "srvurl", ""), 8),
        Ops.get_integer(srv, "lifetime", 0)
      )
      deep_copy(tabitem)
    end

    # Process Tree Items
    def createTreeItem(_Tree, srvType, _Sub)
      _Tree = deep_copy(_Tree)
      _Sub = deep_copy(_Sub)
      _Tree = Wizard.AddTreeItem(
        _Tree,
        "",
        srvType,
        Ops.add("service:", srvType)
      )
      _Sub = Builtins.filter(_Sub) { |s| s != "" }
      Builtins.foreach(_Sub) do |s|
        si = Item()
        _Id = Ops.add(Ops.add(Ops.add("service:", srvType), ":"), s)
        _Tree = Wizard.AddTreeItem(_Tree, Ops.add("service:", srvType), s, _Id)
      end

      deep_copy(_Tree)
    end

    def fillTable(response)
      response = deep_copy(response)
      items = Builtins.maplist(response) { |srv| createTableItem(srv) }

      deep_copy(items)
    end

    def processTree(typeResponse)
      typeResponse = deep_copy(typeResponse)
      treeData = {}
      Builtins.foreach(typeResponse) do |t|
        tok = Builtins.splitstring(t, ":")
        s = []
        s = Builtins.add(s, Ops.get(tok, 2, ""))
        t1 = Ops.get(tok, 1, "")
        if !Builtins.haskey(treeData, t1)
          Ops.set(treeData, t1, s)
        else
          old = Ops.get(treeData, t1, [])
          Ops.set(
            treeData,
            t1,
            Convert.convert(
              Builtins.union(s, old),
              :from => "list",
              :to   => "list <string>"
            )
          )
        end
      end
      deep_copy(treeData)
    end


    def fillTree(typeResponse)
      typeResponse = deep_copy(typeResponse)
      _Tree = []
      data = processTree(typeResponse)
      Builtins.foreach(data) do |type, sub|
        _Tree = createTreeItem(_Tree, type, sub)
      end

      deep_copy(_Tree)
    end
  end
end

Yast::SlpClient.new.main
