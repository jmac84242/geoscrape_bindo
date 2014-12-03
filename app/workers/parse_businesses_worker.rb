require 'nokogiri'
require 'json'

class ParseBusinessesWorker
  include Sidekiq::Worker

  # Los Angeles GEO-BOUNDARY BOX:
  # nw - 34.1592° N, 118.5003° W
  # se - 33.8183° N, 118.0392° W

  # sw_lat, sw_lng = [33.818300, 118.500300]
  # ne_lat, ne_lng = [34.159200, 118.0392]

  def get_next_grid 
    get

  end
  # after first iteration of parsing,
  # sw_lat = sw_lat (until ne_lng < city_bounds)
  # sw_lng = ne_lng
  # ne_lat = ne_lat (until ne_lng < city_bounds )
  # ne_lng = ne_lng + 0.0005 until ne_lng >= city_bounds


  def perform(parent_request_id)
    categories = Category.all
    categories.url_name.each do |category|
      url = "http://www.yelp.com/search/snippet?find_desc=#{category}&find_loc=&l=g%3A#{sw_latitude}%2C#{sw_longitude}%2C#{ne_latitude}%2C#{ne_longitude}&parent_request_id=#{parent_request_id}&request_origin=user"
      begin
        search_results = RestClient.get(url, :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.111 Safari/537.36" )

        if !search_results.nil?
          results = JSON.parse(search_results)
          doc = Nokogiri::HTML(results["search_results"])
          next_url = results["seo_pagination"]["relNextUrl"]
          # if !next_url.empty?
          #   ParseBusinessesWorker.perform_async(next_url)
          # end

          doc.css('ul.search-results div.search-result').each do |element|
            name = element.css('.media-story .biz-name').text
            puts "****BUSINESS******"
            puts "name #{name}"

            img_node = element.css('.media-avatar img:first')
            image = img_node.xpath("@*[starts-with(name(), 'src')]").text
            puts "image #{image}"
            data_key = element.xpath("@*[starts-with(name(), 'data-key')]").text.to_i

            full_address_nodeset = element.css('.secondary-attributes address:first')
            if !full_address_nodeset.empty?
              #full_address_nodeset is a nokogiri nodeset with one node.
              full_address = full_address_nodeset.first.children
              street_address = full_address.first.text.strip 
              puts "#{street_address}"
              zipcode = full_address.text.split(' ')[-1].to_i
              if zipcode.is_a?(Integer)
                zipcode = zipcode
              end
              puts "zipcode = #{zipcode}"
              state = full_address.text.split(' ')[-2]
              puts "state #{state}"
            
              city_name = city.gsub("_", " ")
              puts "city #{city_name}"
              category = category

              exists = Business.where(name: name, address: street_address)
              if exists.size <= 0
                business = Business.create({
                  name: name,
                  address: street_address,
                  zipcode: zipcode,
                  city: city_name,
                  state: state,
                  image: image,
                  category: Category.find_by(name: category)
                })
              
                html_page.css('script').map(&:text)
               
                map_results = results["search_map"]["markers"]
                loc = map_results[data_key.to_s] if map_results.has_key?(data_key.to_s)
                puts "loc #{loc}"
                if loc.present?
                  business.location = Location.new(loc['location'])
                  business.save
                end
              end
            end
          end
        end

      rescue RestClient::ResourceNotFound => ex
        puts "after first rescue #{ex}"
      rescue Exception => e
        puts "after exception #{e}"
      end
    end
  end

end