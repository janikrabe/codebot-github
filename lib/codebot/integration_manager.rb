# frozen_string_literal: true

require 'codebot/network_manager'
require 'codebot/command_error'

module Codebot
  # This class manages the integrations associated with a configuration.
  class IntegrationManager # rubocop:disable Metrics/ClassLength
    # @return [Config] the configuration managed by this class
    attr_reader :config

    # Constructs a new integration manager for a specified configuration.
    #
    # @param config [Config] the configuration to manage
    def initialize(config)
      @config = config
    end

    # Creates a new integration from the given parameters.
    #
    # @param params [Hash] the parameters to initialize the integration with
    def create(params)
      integration = Integration.new(
        params.merge(config: { networks: @config.networks })
      )
      @config.transaction do
        check_available!(integration.name, integration.endpoint)
        NetworkManager.new(@config).check_channels!(integration)
        @config.integrations << integration
        integration_feedback(integration, :created) unless params[:quiet]
      end
    end

    # Updates an integration with the given parameters.
    #
    # @param name [String] the current name of the integration to update
    # @param params [Hash] the parameters to update the integration with
    def update(name, params)
      @config.transaction do
        integration = find_integration!(name)
        check_available_except!(params[:name], params[:endpoint], integration)
        update_channels!(integration, params)
        NetworkManager.new(@config).check_channels!(integration)
        integration.update!(params)
        integration_feedback(integration, :updated) unless params[:quiet]
      end
    end

    # Destroys an integration.
    #
    # @param name [String] the name of the integration to destroy
    # @param params [Hash] the command-line options
    def destroy(name, params)
      @config.transaction do
        integration = find_integration!(name)
        @config.integrations.delete integration
        integration_feedback(integration, :destroyed) unless params[:quiet]
      end
    end

    # Lists all integrations, or integrations with names containing the given
    # search term.
    #
    # @param search [String, nil] an optional search term
    def list(search)
      @config.transaction do
        integrations = @config.integrations.dup
        unless search.nil?
          integrations.select! do |intg|
            intg.name.downcase.include? search.downcase
          end
        end
        puts 'No integrations found' if integrations.empty?
        integrations.each { |intg| show_integration intg }
      end
    end

    # Finds an integration given its name.
    #
    # @param name [String] the name to search for
    # @return [Integration, nil] the integration, or +nil+ if none was found
    def find_integration(name)
      @config.integrations.find { |intg| intg.name_eql? name }
    end

    # Finds an integration given its endpoint.
    #
    # @param endpoint [String] the endpoint to search for
    # @return [Integration, nil] the integration, or +nil+ if none was found
    def find_integration_by_endpoint(endpoint)
      @config.integrations.find { |intg| intg.endpoint_eql? endpoint }
    end

    # Finds an integration given its name.
    #
    # @param name [String] the name to search for
    # @raise [CommandError] if no integration with the given name exists
    # @return [Integration] the integration
    def find_integration!(name)
      integration = find_integration(name)
      return integration unless integration.nil?

      raise CommandError, "an integration with the name #{name.inspect} " \
                          'does not exist'
    end

    private

    # Checks that the specified name is available for use.
    #
    # @param name [String] the name to check for
    # @raise [CommandError] if the name is already taken
    def check_name_available!(name)
      return unless find_integration(name)

      raise CommandError, "an integration with the name #{name.inspect} " \
                          'already exists'
    end

    # Checks that the specified endpoint is available for use.
    #
    # @param endpoint [String] the endpoint to check for
    # @raise [CommandError] if the endpoint is already taken
    def check_endpoint_available!(endpoint)
      return unless find_integration_by_endpoint(endpoint)

      raise CommandError, 'an integration with the endpoint ' \
                          "#{endpoint.inspect} already exists"
    end

    # Checks that the specified name and endpoint are available for use.
    #
    # @param name [String] the name to check for
    # @param endpoint [String] the endpoint to check for
    # @raise [CommandError] if name or endpoint are already taken
    def check_available!(name, endpoint)
      check_name_available!(name) unless name.nil?
      check_endpoint_available!(endpoint) unless endpoint.nil?
    end

    # Checks that the specified name and endpoint are available for use by the
    # specified integration.
    #
    # @param name [String] the name to check for
    # @param endpoint [String] the endpoint to check for
    # @param intg [Integration] the integration to ignore
    # @raise [CommandError] if name or endpoint are already taken
    def check_available_except!(name, endpoint, intg)
      check_name_available!(name) unless name.nil? || intg.name_eql?(name)
      return if endpoint.nil? || intg.endpoint_eql?(endpoint)

      check_endpoint_available!(endpoint)
    end

    # Updates the channels associated with an integration from the specified
    # parameters.
    #
    # @param integration [Integration] the integration
    # @param params [Hash] the parameters to update the integration with. Valid
    #                      keys are +:clear_channels+ to clear the channel list
    #                      before proceeding, +:add_channel+ to add the given
    #                      channels, and +:delete_channel+ to delete the given
    #                      channels from the integration. All keys are optional.
    #                      The value of +:clear_channels+ should be a boolean.
    #                      The value of +:add_channel+ should be a hash of the
    #                      form +identifier => params+, and +:remove_channel+
    #                      should be an array of channel identifiers to remove.
    def update_channels!(integration, params)
      integration.channels.clear if params[:clear_channels]
      if params[:delete_channel]
        integration.delete_channels!(params[:delete_channel])
      end
      return unless params[:add_channel]

      integration.add_channels!(params[:add_channel],
                                networks: @config.networks)
    end

    # Displays feedback about a change made to an integration.
    #
    # @param integration [Integration] the integration
    # @param action [#to_s] the action (+:created+, +:updated+ or +:destroyed+)
    def integration_feedback(integration, action)
      puts "Integration was successfully #{action}"
      show_integration(integration)
    end

    # Prints information about an integration.
    #
    # @param integration [Integration] the integration
    def show_integration(integration)
      puts "Integration: #{integration.name}"
      puts "\tEndpoint: #{integration.endpoint}"
      puts "\tSecret:   #{show_integration_secret(integration)}"
      if integration.channels.empty?
        puts "\tChannels: (none)"
      else
        puts "\tChannels:"
        show_integration_channels(integration)
      end
    end

    # Returns an integration secret, or "(none required)" if payload integrity
    # verification is disabled.
    #
    # @param integration [Integration] the integration
    # @return [String] the secret or placeholder
    def show_integration_secret(integration)
      return '(none required)' unless integration.verify_payloads?

      integration.secret.to_s
    end

    # Prints information about the channels associated with an integration.
    #
    # @param integration [Integration] the integration
    def show_integration_channels(integration)
      integration.channels.each do |channel|
        puts "\t\t- #{channel.name} on #{channel.network.name}"
        puts "\t\t\tKey: #{channel.key}" if channel.key?
        puts "\t\t\tMessages are sent without joining" if channel.send_external
      end
    end
  end
end
