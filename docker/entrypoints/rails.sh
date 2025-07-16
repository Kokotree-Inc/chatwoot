#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

#install missing gems for local dev as we are using base image compiled for production
bundle install

BUNDLE="bundle check"

until $BUNDLE
do
  sleep 2;
done

# Run database migrations if needed
echo "🔄 Running database migrations..."
bundle exec rails db:migrate

# Auto-configure Kokotree branding
echo "🎨 Setting up Kokotree branding..."
bundle exec rails runner "
begin
  # Update INSTALLATION_NAME
  config = InstallationConfig.find_or_create_by(name: 'INSTALLATION_NAME')
  unless config.value == 'Kokotree Chat'
    config.update!(value: 'Kokotree Chat')
    puts '✅ Updated INSTALLATION_NAME to: Kokotree Chat'
  end

  # Update BRAND_NAME
  config = InstallationConfig.find_or_create_by(name: 'BRAND_NAME')
  unless config.value == 'Kokotree Chat'
    config.update!(value: 'Kokotree Chat')
    puts '✅ Updated BRAND_NAME to: Kokotree Chat'
  end

  # Update BRAND_URL if you have a website
  config = InstallationConfig.find_or_create_by(name: 'BRAND_URL')
  unless config.value == 'https://kokotree.com'
    config.update!(value: 'https://kokotree.com')
    puts '✅ Updated BRAND_URL to: https://kokotree.com'
  end

  # Update WIDGET_BRAND_URL
  config = InstallationConfig.find_or_create_by(name: 'WIDGET_BRAND_URL')
  unless config.value == 'https://kokotree.com'
    config.update!(value: 'https://kokotree.com')
    puts '✅ Updated WIDGET_BRAND_URL to: https://kokotree.com'
  end

  # Clear the cache
  GlobalConfig.clear_cache
  puts '🎉 Kokotree branding configured successfully!'
rescue => e
  puts 'ℹ️  Branding setup will run after database is fully initialized'
end
"

# Execute the main process of the container
exec "$@"
