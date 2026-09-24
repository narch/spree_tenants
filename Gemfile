source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

gem 'rails-controller-testing'

# Pinned to the version the host app (tcb) runs in production.
spree_opts = '5.1.6'
gem 'spree', spree_opts
gem 'spree_admin', spree_opts
gem 'spree_emails', spree_opts
gem 'spree_storefront', spree_opts

gem 'mysql2' if ENV['DB'] == 'mysql' || ENV['CI']
gem 'pg' if ENV['DB'] == 'postgres' || ENV['CI']

gem 'sqlite3', '>= 2.0'

gemspec
