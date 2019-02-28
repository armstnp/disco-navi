require 'hashie'
require 'httparty'

module GW2
  module API
    class Request
      @@BASE_URL = "https://api.guildwars2.com/v2/"

      def initialize(path:, params: {})
        unless path.is_a?(Array) && path.all? { |x| x.is_a? String }
          raise "Expected path segment array; received #{path}"
        end

        unless params.is_a? Hash
          raise "Expected params hash; received #{params}"
        end

        @path = path
        @params = params
      end

      def execute
        url = build_url

        http_response = HTTParty.get url
        raise "Failed to call #{url}: #{http_response}" unless http_response.success?

        resp = http_response.parsed_response
        if resp.is_a? Hash
          Response.new(resp).symbolize_keys!
        elsif resp.is_a? Array
          resp.map! { |x| x.is_a?(Hash) ? Response.new(x).symbolize_keys! : x }
          resp.extend Hashie::Extensions::DeepFind
          resp.extend Hashie::Extensions::DeepLocate
        else
          resp
        end
      end

      private

      def build_url
        params_str = params.map { |(k, v)| "#{k}=#{v}" } * '&'
        url = @@BASE_URL + (path * '/')
        url = "#{url}?#{params_str}" unless params_str.empty?
        url
      end

      attr_reader :path, :params
    end

    class Response < Hash
      include Hashie::Extensions::SymbolizeKeys
      include Hashie::Extensions::MergeInitializer
      include Hashie::Extensions::DeepFetch
      include Hashie::Extensions::DeepFind
      include Hashie::Extensions::DeepLocate
    end

    class Endpoint
      class << self
        def authorized
          undef_method :"authorized?" if method_defined? :"authorized?"
          define_method(:"authorized?") { true }
        end

        def segments(*segs)
          undef_method :segments if method_defined? :segments
          define_method(:segments) { segs }
        end

        def params(*ps)
          undef_method :params if method_defined? :params
          ps_hash = ps.map { |p| [p, p] }.to_h
          define_method(:params) { ps_hash }
        end
      end

      def authorized?
        false
      end

      def segments
        raise "No segments defined"
      end

      def params
        {}
      end

      def path(context)
        segments.map { |seg| seg.is_a?(Symbol) ? context.fetch(seg) : seg }
      end

      def full_params(context)
        ps = params
        ps.merge!({ access_token: :token}) if authorized?
        ps.map { |(k, v)| [k, (v.is_a?(Symbol) ? context.fetch(v) : v)] }.to_h
      end

      def request(**context)
        Request.new path: path(context), params: full_params(context)
      end

      def self.request(**context)
        self.new.request(**context).execute
      end
    end

    class Guild < Endpoint
      segments 'guild', :id
    end

    class GuildDetails < Endpoint
      authorized
      segments 'guild', :id
    end

    class GuildSearch < Endpoint
      segments 'guild', 'search'
      params :name
    end

    class GuildUpgradeCatalogSingle < Endpoint
      segments 'guild', 'upgrades', :id
    end

    class GuildUpgradeCatalogMany < Endpoint
      segments 'guild', 'upgrades'
      params :ids
    end

    class GuildTreasury < Endpoint
      authorized
      segments 'guild', :id, 'treasury'
    end

    class GuildUpgrades < Endpoint
      authorized
      segments 'guild', :id, 'upgrades'
    end

    class GuildLog < Endpoint
      authorized
      segments 'guild', :id, 'log'
    end

    class ItemCatalogSingle < Endpoint
      segments 'items', :id
    end

    class ItemCatalogMany < Endpoint
      segments 'items'
      params :ids
    end

    class RenderedGuildLogo
      def initialize(guild_name)
        @guild_name = guild_name
      end

      def url
        "https://guilds.gw2w2w.com/guilds/#{guild_name}/64.png"
      end

      private

      attr_reader :guild_name
    end
  end
end