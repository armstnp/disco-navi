# frozen_string_literal: true

require 'forwardable'
require 'hashie'
require 'httparty'
require 'singleton'
require 'disco_navi/recondition'

module GW2
  # Access port for the GW2 API
  module API
    BASE_URL = 'https://api.guildwars2.com/v2/'

    # Clients of the GW2 API
    module Client
      def self.new(token: nil)
        if token
          AuthorizedClient.new token: token
        else
          UnauthorizedClient.instance
        end
      end

      # A GW2 API client that does not have any authorization token.
      class UnauthorizedClient
        include Singleton

        def initialize
          @item_single = Endpoint.new 'items', :item_id
          @item_many = Endpoint.new('items').params(ids: :item_ids)
          @guild_lite = Endpoint.new 'guild', :guild_id
          @guild_search = Endpoint.new('guild', 'search').params(name: :guild_name)
          @guild_upgrade_single = Endpoint.new 'guild', 'upgrades', :upgrade_id
          @guild_upgrade_many = Endpoint.new('guild', 'upgrades').params(upgrade_ids: :upgrade_ids)
        end

        def get_single_item(item_id:)
          @item_single.request item_id: item_id
        end

        def get_many_items(item_ids:)
          @item_many.request item_ids: item_ids
        end

        def get_guild(guild_id:)
          @guild_lite.request guild_id: guild_id
        end

        def search_guild_by_name(guild_name:)
          @guild_search.request guild_name: guild_name
        end

        def get_single_guild_upgrade(upgrade_id:)
          @guild_upgrade_single.request upgrade_id: upgrade_id
        end

        def get_many_guild_upgrades(upgrade_ids:)
          @guild_upgrade_many.request upgrade_ids: upgrade_ids
        end

        def inspect
          "#{self.class}"
        end
      end

      # A GW2 API client that possesses and uses an authorization token when applicable.
      class AuthorizedClient
        extend Forwardable

        def_delegators :@client, :get_single_item, :get_many_items, :search_guild_by_name,
                       :get_single_guild_upgrade, :get_many_guild_upgrades

        def initialize(token:)
          @token = token
          @client = UnauthorizedClient.instance

          @guild_full = Endpoint.new('guild', :guild_id).authorized
          @guild_treasury = Endpoint.new('guild', :guild_id, 'treasury').authorized
          @guild_upgrades = Endpoint.new('guild', :guild_id, 'upgrades').authorized
          @guild_log = Endpoint.new('guild', :guild_id, 'log').authorized
        end

        def get_guild(guild_id:)
          # TODO: Add separate method that flat-maps failure only
          @guild_full
            .request(guild_id: guild_id, access_token: token)
            .otherwise_try do |response|
              # Caution: If more status codes proliferate, migrate to independent response type
              if response.code == 403
                client.get_guild guild_id: guild_id
              else
                # Observe that this forces a new failure to be constructed instead of allowing reuse
                Recondition::Failure.new response
              end
            end
        end

        def get_guild_treasury(guild_id:)
          @guild_treasury.request guild_id: guild_id, access_token: token
        end

        # TODO: Select better names for upgrade catalog vs. upgrades built/in-progress for a guild
        def get_guild_upgrades(guild_id:)
          @guild_upgrades.request guild_id: guild_id, access_token: token
        end

        def get_guild_log(guild_id:)
          @guild_log.request guild_id: guild_id, access_token: token
        end

        def inspect
          "#{self.class}(token=#{token[0..4]}***)"
        end

        private

        attr_reader :token, :client
      end
    end

    # Components of a request that may be static or looked up at request time
    module RequestBinding
      def self.new(token)
        case token
        when String
          StaticRequestBinding.new token
        when Symbol
          VariableRequestBinding.new token
        else
          raise "Expected string or token for request binding; received #{token}"
        end
      end

      # A component of an endpoint that has a fixed string value
      class StaticRequestBinding
        def initialize(static_value)
          @static_value = static_value
        end

        def value(*)
          static_value
        end

        private

        attr_reader :static_value
      end

      # A component of an endpoint that is substituted by key on request
      class VariableRequestBinding
        def initialize(binding_key)
          @binding_key = binding_key
        end

        def value(binding_values)
          unless binding_values.key? binding_key
            raise "No value found for expected binding key #{var}"
          end

          binding_values[binding_key].to_s
        end

        private

        attr_reader :binding_key
      end
    end

    # A GW2 endpoint
    class Endpoint
      def initialize(*path_segments)
        @path_bindings = path_segments.map { |seg| GW2::API::RequestBinding.new seg }
        @param_bindings = []
        @authorizer = NoAuthorization.instance
      end

      def params(**param_binding_hash)
        self.param_bindings =
          param_binding_hash
          .to_a
          .map { |(key, val)| [key, GW2::API::RequestBinding.new(val)] }

        self
      end

      def authorized
        self.authorizer = RequiredAuthorization.instance
        self
      end

      def request(**binding_values)
        bound_path = path_bindings.map { |ps| ps.value binding_values }

        bound_params =
          param_bindings
          .map { |(key, val)| [key, val.value(binding_values)] }
          .to_h
        authorizer.apply_authorization(bound_params, binding_values)

        Request
          .new(path: bound_path, params: bound_params)
          .execute
      end

      # An authorizer that ignores authorization entirely
      class NoAuthorization
        include Singleton

        def apply_authorization(*); end
      end

      # An authorizer that adds a provided access token to the request
      class RequiredAuthorization
        include Singleton

        def initialize
          @binding = GW2::API::RequestBinding.new(:access_token)
        end

        def apply_authorization(params, binding_values)
          access_token = binding.value binding_values
          params[:access_token] = access_token
        end

        private

        attr_reader :binding
      end

      private_constant :NoAuthorization, :RequiredAuthorization

      private

      attr_reader :path_bindings
      attr_accessor :param_bindings, :authorizer
    end

    # A request to the GW2 API
    class Request
      def initialize(path:, params: {})
        unless path.is_a?(Array) && path.all? { |x| x.is_a? String }
          raise "Expected path segment array; received #{path}"
        end

        raise "Expected params hash; received #{params}" unless params.is_a? Hash

        @path = path
        @params = params
      end

      def execute
        url = build_url

        http_response = HTTParty.get url
        if http_response.success?
          Recondition::Success.new GW2::API.build_response(http_response.parsed_response)
        else
          Recondition::Failure.new http_response
        end
      end

      private

      def build_url
        params_str = params.map { |(k, v)| "#{k}=#{v}" } * '&'
        url = BASE_URL + (path * '/')
        url = "#{url}?#{params_str}" unless params_str.empty?
        url
      end

      attr_reader :path, :params
    end

    def self.build_response(resp_body)
      case resp_body
      when ::Hash
        Response.new(resp_body)
      when ::Array
        resp_body.map! { |x| x.is_a?(::Hash) ? Response.new(x) : x }
        resp_body.extend Hashie::Extensions::DeepFind
        resp_body.extend Hashie::Extensions::DeepLocate
      else
        resp_body # Note that this may not fit the expected roles...
      end
    end

    # A response from the GW2 API
    class Response < Hash
      include Hashie::Extensions::SymbolizeKeys
      include Hashie::Extensions::MergeInitializer
      include Hashie::Extensions::DeepFetch
      include Hashie::Extensions::DeepFind
      include Hashie::Extensions::DeepLocate

      def initialize(hash)
        super(hash)
        symbolize_keys!
      end
    end
  end
end
