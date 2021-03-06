require 'rest_client'

class MainController < ApplicationController

  def scrape

    # Customize values below.
    # Choose any grid size/location and parser should work
    geo_area_bounds = {
      sw_lat: 33.74, 
      sw_lng: 118.45, 
      ne_lat: 34.20, 
      ne_lng: 118.00
    }

    grid = Grid.new
    geo_grid = grid.build(geo_area_bounds)
    categories = Category.all
    pr_id = ParentRequestId.new
    request_id = pr_id.get_id

    geo_grid.each do |bound|
      sleep 2
      categories.each do |category|
        sleep 3
        crawler = YelpWorker.perform_async(bound, category.url_name, request_id)
      end
    end
  end
end