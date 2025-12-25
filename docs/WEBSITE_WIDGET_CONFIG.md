# Getting Website Widget Configuration

This guide shows how to get the `BASE_URL` and `WEBSITE_TOKEN` needed for the Chatwoot support widget integration.

## Configuration Values

```javascript
SUPPORT_WIDGET: {
  BASE_URL: process.env.NEXT_PUBLIC_SUPPORT_WIDGET_BASE_URL || "http://localhost:3100",
  WEBSITE_TOKEN: process.env.NEXT_PUBLIC_SUPPORT_WIDGET_TOKEN || "YOUR_WEBSITE_TOKEN_HERE",
}
```

## BASE_URL

For local development, use:
- `http://localhost:3100` (development Docker setup)

For production, use:
- Your Chatwoot instance URL (e.g., `https://chat.apaya.com`)

Set via environment variable: `NEXT_PUBLIC_SUPPORT_WIDGET_BASE_URL`

## WEBSITE_TOKEN

The website token is automatically generated for each web widget inbox. Here are several ways to get it:

### Method 1: Via Chatwoot Dashboard (Easiest)

1. Log in to Chatwoot: http://localhost:3100
   - Email: `john@acme.inc`
   - Password: `Password1!`

2. Navigate to **Settings → Inboxes**

3. Click on your **Website** inbox (or create one if it doesn't exist)

4. Scroll to the **Website Widget Setup** section

5. You'll see the widget script with the `websiteToken` in it:
   ```javascript
   websiteToken: 'YOUR_WEBSITE_TOKEN_HERE'
   ```

6. Copy the token value

### Method 2: Via Rails Console

```bash
# Access Rails console in Docker
docker compose exec rails bundle exec rails console
```

Then in the console:

```ruby
# Find all web widget inboxes
Channel::WebWidget.all.each do |widget|
  puts "Inbox: #{widget.inbox.name}"
  puts "Website Token: #{widget.website_token}"
  puts "Website URL: #{widget.website_url}"
  puts "---"
end

# Or get the first web widget's token
widget = Channel::WebWidget.first
puts widget.website_token if widget
```

### Method 3: Via API

```bash
# Get your account access token from Chatwoot dashboard
# Settings → Profile → API Tokens

# Get all inboxes (includes website_token for web widgets)
curl -X GET \
  "http://localhost:3100/api/v1/accounts/1/inboxes" \
  -H "api_access_token: YOUR_API_ACCESS_TOKEN"

# Response will include website_token in the channel data for web widgets
```

Example API response:
```json
{
  "id": 1,
  "name": "Acme Support",
  "channel_type": "Channel::WebWidget",
  "website_token": "LSw4pTkvrNsgUSPxe3Xm6APg",
  "website_url": "https://acme.inc",
  ...
}
```

### Method 4: Direct Database Query

```bash
# Access PostgreSQL console
docker compose exec postgres psql -U postgres -d chatwoot_dev

# Query website tokens
SELECT id, website_url, website_token 
FROM channel_web_widgets;

# Or with inbox name
SELECT 
  i.name as inbox_name,
  cw.website_url,
  cw.website_token
FROM channel_web_widgets cw
JOIN inboxes i ON i.channel_id = cw.id
WHERE i.channel_type = 'Channel::WebWidget';
```

## Default Token (from Seeds)

When you run `db:chatwoot_prepare`, a default web widget is created with a website token. You can check this token using any of the methods above.

The token will be randomly generated (using Rails `has_secure_token`), so it will be different each time you reset the database.

## Complete Example

```javascript
// .env.local or your environment variables
NEXT_PUBLIC_SUPPORT_WIDGET_BASE_URL=http://localhost:3100
NEXT_PUBLIC_SUPPORT_WIDGET_TOKEN=LSw4pTkvrNsgUSPxe3Xm6APg

// In your Next.js config
SUPPORT_WIDGET: {
  BASE_URL: process.env.NEXT_PUBLIC_SUPPORT_WIDGET_BASE_URL || "http://localhost:3100",
  WEBSITE_TOKEN: process.env.NEXT_PUBLIC_SUPPORT_WIDGET_TOKEN || "LSw4pTkvrNsgUSPxe3Xm6APg",
}
```

## Quick One-Liner (Rails Console)

```bash
docker compose exec rails bundle exec rails runner "puts Channel::WebWidget.first&.website_token"
```

This will output just the website token, perfect for copying into your environment variables.

