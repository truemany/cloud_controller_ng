module VCAP::CloudController

  # This controller is an experiment breaking away from the old
  # cloudcontroller metaprogramming. We manually generate the JSON
  # expected by CFoundry and CF.
  class ServiceBrokersController < RestController::Base
    get '/v2/service_brokers', :enumerate
    post '/v2/service_brokers', :create
    put '/v2/service_brokers/:guid', :update
    delete '/v2/service_brokers/:guid', :delete

    # poor man's before filter
    def dispatch(op, *args)
      require_admin
      super
    end

    def enumerate
      headers = {}
      brokers = Models::ServiceBroker.filter(build_filter)

      resources = brokers.map { |broker| broker_hash(broker) }
      page = 1
      page_size = resources.count
      paginated_dataset = brokers.extension(:pagination).paginate(page, page_size)
      body = paginate(resources, paginated_dataset, '/v2/service_brokers')
      #body = paginate( brokers.map { |broker| broker_hash(broker) } )
      [HTTP::OK, headers, body.to_json]
    end

    def create
      broker = Models::ServiceBroker.new(Yajl::Parser.parse(body))
      broker.check! if broker.valid?
      broker.save

      body = broker_hash(broker)
      headers = {"Location" => url_of(broker) }

      [HTTP::CREATED, headers, body.to_json]
    end

    def update(guid)
      parsed = Yajl::Parser.parse(body)

      b = Models::ServiceBroker.find(:guid => guid)
      return HTTP::NOT_FOUND unless b

      b.name = parsed['name'] if parsed.key?('name')
      b.broker_url = parsed['broker_url'] if parsed.key?('broker_url')
      b.token = parsed['token'] if parsed.key?('token')

      b.check! if b.valid?
      b.save

      body = broker_hash(b)
      [ HTTP::OK, {}, body.to_json ]
    end

    def delete(guid)
      broker = Models::ServiceBroker.find(:guid => guid)
      return HTTP::NOT_FOUND unless broker
      broker.destroy
      HTTP::NO_CONTENT
    end

    def self.translate_validation_exception(e, _)
      if e.errors.on(:name) && e.errors.on(:name).include?(:unique)
        Errors::ServiceBrokerNameTaken.new(e.model.name)
      elsif e.errors.on(:broker_url) && e.errors.on(:broker_url).include?(:unique)
        Errors::ServiceBrokerUrlTaken.new(e.model.broker_url)
      else
        Errors::ServiceBrokerInvalid.new(e.errors.full_messages)
      end
    end

    private

    def require_admin
      raise NotAuthenticated unless user
      raise NotAuthorized unless roles.admin?
    end

    def build_filter
      q = params['q']
      if q && q.start_with?('name:')
        {:name => q.split(':')[1]}
      else
        {}
      end
    end

    def paginate()

    end

    #def paginate(resources)
    #  {
    #    'total_results' => resources.count,
    #    'total_pages' => 1,
    #    'prev_url' => nil,
    #    'next_url' => nil,
    #    'resources' => resources
    #  }
    #end

    def broker_hash(broker)
      {
        'metadata' => {
          'guid' => broker.guid,
          'url' => url_of(broker),
          'created_at' => broker.created_at,
          'updated_at' => broker.updated_at,
        },
        'entity' => {
          'name' => broker.name,
          'broker_url' => broker.broker_url,
        }
      }
    end

    def url_of(broker)
      "#{self.class.path}/#{broker.guid}"
    end
  end
end
