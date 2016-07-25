# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast"
require "ui/dialog"

module Yast
  module Dialogs
    # This class implements a services selection dialog.
    class ServiceSelection < ::UI::Dialog
      Yast.import "UI"
      Yast.import "Label"
      Yast.import "Report"

      # @return [Array<SlpServiceClass::Service] list of services to show
      attr_reader :services
      # @return [String] dialog's heading
      attr_reader :heading
      # @return [String] dialog's description
      attr_reader :description
      # @return [String] message to be shown when no service was selected
      attr_reader :no_selected_msg
      # @return [SlpServiceClass::Service] initially selected service
      attr_reader :initial

      # Run dialog
      #
      # The return value will be:
      # * A service in case one was selected
      # * :cancel symbol if the dialog was canceled
      #
      # @example Select some service
      #   Yast::Dialogs::SelectionServiceDialog.run(services) #=> :scc
      #     #=> #<Yast::SlpServiceClass::Service...>
      #
      # @example Press the 'cancel' button
      #   Yast::Dialogs::SelectionServiceDialog.run(services) #=> :cancel
      #
      # @param services        [Array<SlpServiceClass::Service] list of services to show
      # @param heading         [String] Dialog's heading
      # @param description     [String] Dialog's description (to be shown on top of the list)
      # @param no_selected_msg [String] Message to be shown when no service was selected
      # @return [SlpServiceClass::Service,Symbol] selected service or :cancel symbol
      #
      # @see #run
      def self.run(services:, heading: nil, description: nil)
        new(services: services, heading: nil, description: nil,
            no_selected_msg: nil, initial: nil).run
      end

      # Constructor
      #
      # @param services        [Array<SlpServiceClass::Service>] list of services to show
      # @param heading         [String] Dialog's heading
      # @param description     [String] Dialog's description (to be shown on top of the list)
      # @param no_selected_msg [String] Message to be shown when no service was selected
      # @param initial         [SlpServiceClass::Service] initially selected service
      def initialize(services: [], heading: nil, description: nil, no_selected_msg: nil, initial: nil)
        super()

        textdomain "registration"

        @services = services
        @heading = heading || _("Service selection")
        @description = description || _("Select a detected service from the list.")
        @no_selected_msg = no_selected_msg || _("No service was selected.")
        @initial = initial || services.first
      end

      # Handler for the Ok button
      #
      # If no option was selected, a error message is shown.
      def ok_handler
        selected = Yast::UI.QueryWidget(Id(:services), :CurrentButton)
        if !selected
          Yast::Report.Error(no_selected_msg)
        else
          finish_dialog(services[selected.to_i])
        end
      end

      # Handler for the cancel button
      def cancel_handler
        finish_dialog(:cancel)
      end

    protected

      # Dialog's initial content
      #
      # @return [Yast::Term] Content
      def dialog_content
        MarginBox(2, 0.5,
          VBox(
            # popup heading (in bold)
            Heading(heading),
            VSpacing(0.5),
            Label(description),
            VSpacing(0.5),
            RadioButtonGroup(
              Id(:services),
              Left(
                HVSquash(
                  VBox(*services_radio_buttons)
                )
              )
            ),
            VSpacing(Opt(:vstretch), 1),
            button_box
          ))
      end

      # Dialog options
      #
      # @return [Yast::Term] Dialog's options
      def dialog_options
        Yast::Term.new(:opt, :decorated)
      end

      # Return dialog's buttons
      #
      # @return [Yast::Term] Buttons' description
      def button_box
        ButtonBox(
          PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
          PushButton(Id(:cancel), Yast::Label.CancelButton)
        )
      end

      # Return service radio buttons
      #
      # @return [Yast::Term] Service radio button's description
      def services_radio_buttons
        services.map.with_index do |service, idx|
          Left(
            RadioButton(Id(idx.to_s), service_to_description(service), service == initial)
          )
        end
      end

      # Return the service description to be shown to the user
      #
      # @return [String] Service description
      def service_to_description(service)
        url = service.slp_url.sub(service.slp_type, service.protocol)
        descr = service.attributes.description

        # display URL and the description if it is present
        (descr && !descr.empty?) ? "#{descr} (#{url})" : url
      end
    end
  end
end
