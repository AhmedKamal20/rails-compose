run "rm template.rb"

# gem 'friendly_id'
# gem 'devise'
# gem 'devise_invitable'
gem 'sidekiq'
# gem 'name_of_person'
# gem 'pretender'
# gem 'pundit'
# gem 'sitemap_generator'
# gem 'inherited_resources'
# gem 'has_scope'
# gem 'responders'
gem 'pry-rails'
# gem 'tailwindcss-rails'
# gem 'faker'

gem_group :development do
  # gem 'annotate'
  # gem 'priscilla'
  # gem 'table_print'
  # gem 'awesome_print'
end

after_bundle do
  # Initial commit
  git commit: "--allow-empty -m 'Initial commit'"
  git add: '.'
  git commit: "-a -m 'Generate Rails App'"

  # Migrate the DB
  rails_command "db:create db:migrate"
  git add: '.'
  git commit: "-a -m 'Migrate DB'"

  # Install active storage
  rails_command "active_storage:install"
  rails_command "db:migrate"
  git add: '.'
  git commit: "-a -m 'Install active storage'"

  # Install friendly id
  # generate "friendly_id"
  # rails_command "db:migrate"
  # git add: '.'
  # git commit: "-a -m 'Use friendly id'"

  # Install Devise
  # generate "devise:install"
  # generate "devise_invitable:install"

  ## Configure Devise to handle TURBO_STREAM requests like HTML requests
  # insert_into_file "config/initializers/devise.rb", "  config.navigational_formats = ['/', :html, :turbo_stream]", after: "Devise.setup do |config|\n"

  # content = <<~RUBY
  #   class TurboFailureApp < Devise::FailureApp
  #     def respond
  #       if request_format == :turbo_stream
  #         redirect
  #       else
  #         super
  #       end
  #     end

  #     def skip_format?
  #       %w(html turbo_stream */*).include? request_format.to_s
  #     end
  #   end
  # RUBY
  # insert_into_file 'config/initializers/devise.rb', "#{content}\n", after: "# frozen_string_literal: true\n"

  # content = <<-RUBY
  # config.warden do |manager|
  #   manager.failure_app = TurboFailureApp
  # end
  # RUBY
  # insert_into_file 'config/initializers/devise.rb', "#{content}\n", after: "# ==> Warden configuration\n"

  environment "config.action_mailer.default_url_options = { host: ENV['HOST'] }", env: 'development'
  # generate :devise, "User", "first_name", "last_name", "admin:boolean"
  # generate :devise_invitable, "User"

  ## Set admin default to false
  # in_root do
  #   migration = Dir.glob("db/migrate/*").max_by { |f| File.mtime(f) }
  #   gsub_file migration, /:admin/, ":admin, default: false"
  # end

  # gsub_file "config/initializers/devise.rb", /  # config.secret_key = .+/, "  config.secret_key = Rails.application.credentials.secret_key_base"
  # rails_command "db:migrate"
  # git add: '.'
  # git commit: "-a -m 'Install devise'"

  # Install sidekiq
  # content = <<-RUBY
  # authenticate :user, lambda { |u| u.admin? } do
  #   mount Sidekiq::Web => '/sidekiq'
  # end
  # RUBY

  # environment "config.active_job.queue_adapter = :sidekiq"
  # insert_into_file "config/routes.rb", "require 'sidekiq/web'\n\n", before: "Rails.application.routes.draw do"
  # insert_into_file "config/routes.rb", "#{content}\n", after: "Rails.application.routes.draw do\n"
  # git add: '.'
  # git commit: "-a -m 'Install sidekiq'"

  # Install Tailwind
  # rails_command "tailwindcss:install"
  # git add: '.'
  # git commit: "-a -m 'Install Tailwind'"

  # Install annotate
  # generate 'annotate:install'
  # gsub_file "lib/tasks/auto_annotate_models.rake", /before/, "after"
  # gsub_file "lib/tasks/auto_annotate_models.rake", /'show_complete_foreign_keys'  => 'false'/, "'show_complete_foreign_keys'  => 'true'"
  # rails_command "db:migrate"
  # git add: '.'
  # git commit: "-a -m 'Install annotate'"

  # Add Home Controller
  generate :controller, "home index contact about terms privacy", "--skip-routes"
  route "root to: 'home#index'"
  route "get '/contact', to: 'home#contact'"
  route "get '/about', to: 'home#about'"
  route "get '/terms', to: 'home#terms'"
  route "get '/privacy', to: 'home#privacy'"
  git add: '.'
  git commit: "-a -m 'Add Home Controller'"

  # Add Some Config
  # You can change application name inside: ./config/application.rb
  environment "config.hosts << ENV.fetch('HOST') { 'app.example.io' }"
  environment "config.application_name = Rails.application.class.module_parent_name"
  # content = <<~RUBY
  #   config.action_mailer.delivery_method = :smtp
  #   config.action_mailer.perform_deliveries = true
  #   config.action_mailer.default charset: 'utf-8'

  #   config.action_mailer.smtp_settings = {
  #     address: 'mailcatcher',
  #     port: 1025,
  #   }
  # RUBY
  environment "config.web_console.permissions = '172.0.0.0/0'", env: 'development'
  # environment "#{content}\n", env: 'development'
  insert_into_file "Procfile.dev", " -b 0.0.0.0", after: "3000"
  git add: '.'
  git commit: "-a -m 'Add Some Config'"

  # Generate the SiteMap
  # rails_command "sitemap:install"
  # git add: '.'
  # git commit: "-a -m 'Generate the SiteMap'"
end
