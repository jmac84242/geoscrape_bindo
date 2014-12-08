class CreateCategories < ActiveRecord::Migration
  def change
    create_table :categories do |t|
      t.string :url_name
      t.string :display_name
      t.string :color
      t.references :business, index: true


      t.timestamps
    end
  end
end
