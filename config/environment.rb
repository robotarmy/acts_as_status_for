require 'rails/all'

module ActsAsStatus
  class Application < Rails::Application
  end
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)

