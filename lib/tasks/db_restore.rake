namespace :db_repair do
  desc "Repair sequences in PostgreSQL"
  task sequences: :environment do
    ActiveRecord::Base.connection.tables.each do |table|
      if ActiveRecord::Base.connection.column_exists?(table, "id")
        result = ActiveRecord::Base.connection.select_one("SELECT max(id) FROM #{table}")
        if result["max"]
          puts "Update public.#{table}_id_seq = #{result['max']}"
          ActiveRecord::Base.connection.select_one("SELECT setval('public.#{table}_id_seq', #{result['max']}, true);")
        end
      end
    end
  end
end
