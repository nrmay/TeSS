require 'ingestors/ingestor_event'
require 'open-uri'
require 'csv'

class IngestorEventRest < IngestorEvent

  def initialize
    super

    @RestSources = [
      { name: 'ElixirTeSS',
        url: 'https://tess.elixir-europe.org/',
        process: method(:process_elixir) },
      { name: 'Eventbrite API v3',
        url: 'https://www.eventbriteapi.com/v3/',
        process: method(:process_eventbrite) }
    ]

    # cached API object responses
    @eventbrite_objects = {}
  end

  def read(url, token)
    @messages << "#{self.class.name}.#{__method__} url[#{url}] token[#{token}]"
    begin
      process = nil

      # get the rest source
      @RestSources.each do |source|
        if url.starts_with? source[:url]
          process = source[:process]
        end
      end

      # abort if no source found for url
      raise "REST source not found for URL: #{url}" if process.nil?

      # process url
      process.call(url, token)

    rescue Exception => e
      @messages << "#{self.class.name} failed with: #{e.message}"
    end

    # finished
    return
  end

  private

  def process_eventbrite(url, token)
    records_read = 0
    records_draft = 0
    records_expired = 0
    records_completed = 0

    begin
      # initialise next_page
      next_page = "#{url}/events/?token=#{token}"

      while next_page
        # execute REST request
        results = get_JSON_response next_page

        # check next page
        next_page = nil
        pagination = results['pagination']
        begin
          unless pagination.nil? or pagination['has_more_items'].nil? or pagination['page_number'].nil?
            if pagination['has_more_items']
              page = pagination['page_number'].to_i
              next_page = "#{url}/events/?page=#{page + 1}&token=#{token}"
            end
          end
        rescue Exception => e
          puts "format next_page failed with: #{e.message}"
        end

        # check events
        events = results['events']
        unless events.nil? or events.empty?
          events.each do |item|
            records_read += 1
            unless item['status'].nil?
              # check status
              case item['status']
              when 'draft'
                records_draft += 1
              when 'completed'
                records_completed += 1
              when 'live'
                # create new event
                event = Event.new

                # check for expired
                event.timezone = item['start']['timezone']
                event.start = item['start']['local']
                event.end = item['end']['local']
                if event.expired?
                  records_expired += 1
                else
                  # set required attributes
                  event.title = item['name']['text'] unless item['name'].nil?
                  event.url = item['url']
                  event.description = convert_description item['description']['html'] unless item['description'].nil?
                  if item['online_event'].nil? or item['online_event'] == false
                    event.online = false
                  else
                    event.online = true
                  end

                  # organizer
                  organizer = get_eventbrite_organizer item['organizer_id'], token
                  event.organizer = organizer['name'] unless organizer.nil?

                  # address fields
                  venue = get_eventbrite_venue item['venue_id'], token
                  unless venue.nil? or venue['address'].nil?
                    address = venue['address']
                    venue = address['address_1']
                    venue += (', ' + address['address_2']) unless address['address_2'].blank?
                    event.venue = venue
                    event.city = address['city']
                    event.country = address['country']
                    event.postcode = address['postal_code']
                    event.latitude = address['latitude']
                    event.longitude = address['longitude']
                  end

                  # set optional attributes
                  event.keywords = []
                  category = get_eventbrite_category item['category_id'], token
                  subcategory = get_eventbrite_subcategory(
                    item['subcategory_id'], item['category_id'], token)
                  event.keywords << category['name'] unless category.nil?
                  event.keywords << subcategory['name'] unless subcategory.nil?

                  unless item['capacity'].nil? or item['capacity'] == 'null'
                    event.capacity = item['capacity'].to_i
                  end

                  event.event_types = []
                  format = get_eventbrite_format item['format_id'], token
                  unless format.nil?
                    type = convert_event_types format['short_name']
                    event.event_types << type unless type.nil?
                  end

                  if item['invite_only'].nil? or !item['invite_only']
                    event.eligibility = 'open_to_all'
                  else
                    event.eligibility = 'by_invitation'
                  end

                  if item['is_free'].nil? or !item['is_free']
                    event.cost_basis = 'charge'
                    event.cost_currency = item['currency']
                  else
                    event.cost_basis = 'free'
                  end

                  # add event to events array
                  add_event(event)
                  @ingested += 1
                end
              else
                # unknown status
              end
            end
          rescue Exception => e
            @messages << "Extract event fields failed with: #{e.message}"
          end
        end
      end

      @messages << "Eventbrite events read[#{records_read}] draft[#{records_draft}] expired[#{records_expired}] completed[#{records_completed}]"
    rescue Exception => e
      @messages << "#{self.class} failed with: #{e.message}"
    end

    # finished
    return
  end

  def get_eventbrite_format(id, token)
    # fields: resource_uri, id, name, name_localized, short_name, short_name_localized
    # initialise cache
    @eventbrite_objects[:formats] = {} if @eventbrite_objects[:formats].nil?

    # populate cache if empty
    if @eventbrite_objects[:formats].empty?
      begin
        url = "https://www.eventbriteapi.com/v3/formats/?token=#{token}"
        response = get_JSON_response url
        unless response.nil? or response['formats'].nil? or !response['formats'].kind_of? Array
          response['formats'].each do |format|
            # add each item to the cache
            @eventbrite_objects[:formats][format['id']] = format
          end
        end
      rescue Exception => e
        @messages << "get Eventbrite format failed with: #{e.message}"
      end
    end

    # return result
    @eventbrite_objects[:formats][id]
  end

  def get_eventbrite_venue(id, token)
    # fields: resource_uri, id, age_restriction, capacity, name,latitude,
    #         longitude, address (address_1, address_2, city, region,
    #                             postal_code, country)

    # initialize cache
    @eventbrite_objects[:venues] = {} if @eventbrite_objects[:venues].nil?

    # abort on bad input
    return nil if id.nil? or id == 'null'

    # not in cache
    unless @eventbrite_objects[:venues].keys.include? id
      begin
        # get from query and add to cache if found
        url = "https://www.eventbriteapi.com/v3/venues/#{id}/?token=#{token}"
        venue = get_JSON_response url
        @eventbrite_objects[:venues][id] = venue unless venue.nil?
      rescue Exception => e
        @messages << "get Eventbrite Venue failed with: #{e.message}"
      end
    end

    # return from cache
    @eventbrite_objects[:venues][id]
  end

  def get_eventbrite_category(id, token)
    # initialize cache
    @eventbrite_objects[:categories] = {} if @eventbrite_objects[:categories].nil?

    # abort on bad input
    return nil if id.nil? or id == 'null'

    # populate cache
    if @eventbrite_objects[:categories].empty?
      begin
        # initialise pagination
        has_more_items = true
        url = "https://www.eventbriteapi.com/v3/categories/?token=#{token}"

        # query until no more pages
        while has_more_items
          # infinite loop guard
          has_more_items = false

          # execute query
          response = get_JSON_response url
          unless response.nil?
            cats = response['categories']
            pagination = response['pagination']

            # process categories
            unless cats.nil? or !cats.kind_of? Array
              cats.each do |cat|
                @eventbrite_objects[:categories][cat['id']] = cat
              end
            end

            # check for next page
            unless pagination.nil?
              has_more_items = pagination['has_more_items']
              page_number = pagination['page_number'] + 1
              url = "https://www.eventbriteapi.com/v3/categories/?page=#{page_number}&token=#{token}"
            end
          end
        end
      rescue Exception => e
        @messages << "get Eventbrite format failed with: #{e.message}"
      end
    end

    # finished
    @eventbrite_objects[:categories][id]
  end

  def get_eventbrite_subcategory(id, category_id, token)
    category = get_eventbrite_category category_id, token

    # abort on bad input
    return nil if category.nil? or id.nil? or id == 'null'

    # get subcategories
    subcategories = category['subcategories']

    if subcategories.nil?
      # populate subcategories
      begin
        url = "#{category['resource_uri']}?token=#{token}"
        response = get_JSON_response url
        unless response.nil?
          # updated cached category
          @eventbrite_objects[:categories][id] = response
          subcategories = response['subcategories']
        end
      rescue Exception => e
        @messages << "get Eventbrite subcategory failed with: #{e.message}"
      end
    end

    # check for subcategory
    unless subcategories.nil? and !subcategories.kind_of?(Array)
      subcategories.each { |sub| return sub if sub['id'] == id }
    end

    # not found
    nil
  end

  def get_eventbrite_organizer(id, token)
    # fields: description (text, html), long_description (text, html),
    #         resource_uri, id, name, url, etc.

    # initialize cache
    @eventbrite_objects[:organizers] = {} if @eventbrite_objects[:organizers].nil?

    # abort on bad input
    return nil if id.nil? or id == 'null'

    # not in cache
    unless @eventbrite_objects[:organizers].keys.include? id
      begin
        # get from query and add to cache if found
        url = "https://www.eventbriteapi.com/v3/organizers/#{id}/?token=#{token}"
        organizer = get_JSON_response url
        @eventbrite_objects[:organizers][id] = organizer unless organizer.nil?
      rescue Exception => e
        @messages << "get Eventbrite Venue failed with: #{e.message}"
      end
    end

    # return from cache
    @eventbrite_objects[:organizers][id]
  end

  def process_elixir(url, token)
    # execute REST request
    results = get_JSON_response url
    data = results['data']

    # extract materials from results
    unless data.nil? or data.size < 1
      data.each do |item|
        begin
          # create new event
          event = Event.new

          # extract event details from
          attr = item['attributes']
          event.title = attr['title']
          event.url = attr['url'].strip unless attr['url'].nil?
          event.description = convert_description attr['description']
          event.start = attr['start']
          event.end = attr['end']
          event.timezone = 'UTC'
          event.contact = attr['contact']
          event.organizer = attr['organizer']
          event.online = attr['online']
          event.city = attr['city']
          event.country = attr['country']
          event.venue = attr['venue']
          event.online = true if attr['venue'] == 'Online'

          # array fields
          event.keywords = []
          attr['keywords'].each { |keyword| event.keywords << keyword } unless attr['keywords'].nil?

          event.host_institutions = []
          attr['host-institutions'].each { |host| event.host_institutions << host } unless attr['host-institutions'].nil?

          # dictionary fields
          event.eligibility = []
          unless attr['eligibility'].nil?
            attr['eligibility'].each do |key|
              value = convert_eligibility(key)
              event.eligibility << value unless value.nil?
            end
          end
          event.event_types = []
          unless attr['event_types'].nil?
            attr['event_types'].each do |key|
              value = convert_event_types(key)
              event.event_types << value unless value.nil?
            end
          end

          # add event to events array
          add_event(event)
          @ingested += 1
        rescue Exception => e
          @messages << "Extract event fields failed with: #{e.message}"
        end
      end
    end
  end

  def get_JSON_response(url)
    response = RestClient::Request.new(method: :get,
                                       url: CGI.unescape_html(url),
                                       verify_ssl: false,
                                       headers: { accept: 'application/vnd.api+json' }).execute
    # check response
    raise "invalid response code: #{response.code}" unless response.code == 200
    JSON.parse(response.to_str)
  end

end
