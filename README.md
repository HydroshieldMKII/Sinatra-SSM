# Sinatra Session Manager

A secure session management system for Ruby Sinatra applications featuring BCrypt password hashing, CSRF protection, account lockout, and thread-safe JSON user storage.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [API Reference](#api-reference)
  - [authenticated?](#authenticated)
  - [authenticate!](#authenticate)
  - [require_authentication!](#require_authentication)
  - [current_user](#current_user)
  - [logout!](#logout)
  - [create_user](#create_user)
  - [csrf_token](#csrf_token)
  - [verify_csrf_token!](#verify_csrf_token)
- [Security Features](#security-features)
- [Common Issues](#common-issues)

## Installation

Clone the repository

```bash
git clone https://github.com/HydroshieldMKII/Sinatra-SSM.git
cd Sinatra-SSM
```

Install dependencies

```bash
bundle install
```

Required gems:
- sinatra
- bcrypt
- rack-session

## Configuration

### JSON User Storage

Users are stored in a JSON file with the following structure:

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "admin",
    "password_hash": "$2a$12$...",
    "created_at": 1703001600,
    "failed_attempts": 0,
    "locked_until": null,
    "last_login": 1703088000
  }
]
```

### Configuration Options

Configure the session manager in your Sinatra app:

```ruby
configure do
  session_config.session_secret = ENV['SESSION_SECRET'] || SecureRandom.hex(64)
  session_config.users_store = ENV['USERS_PATH'] || 'users.json'
  session_config.cookie_name = 'my_app.session'
  session_config.session_expire = 86400  # 24 hours
  session_config.login_path = '/login'
  session_config.bcrypt_cost = 12
  session_config.min_password_length = 12
  session_config.max_failed_attempts = 5
  session_config.lockout_duration = 900  # 15 minutes
  session_config.session_rotation = true
  session_config.csrf_protection = true
  session_config.validate!
end
```

## Usage

### Basic Setup

```ruby
require 'sinatra/base'
require_relative 'SimpleSessionManager'

class App < Sinatra::Base
  register Sinatra::SessionManager
  
  configure do
    session_config.session_secret = SecureRandom.hex(64)
    session_config.users_store = 'users.json'
    session_config.validate!
    
    use Rack::Session::Cookie,
        key: session_config.cookie_name,
        secret: session_config.session_secret,
        expire_after: session_config.session_expire,
        httponly: true,
        secure: production?,
        same_site: :lax
  end
  
  get '/login' do
    erb :login, locals: { csrf_token: csrf_token }
  end
  
  post '/login' do
    if authenticate!(params[:username], params[:password])
      redirect '/dashboard'
    else
      status 401
      erb :login, locals: { 
        error_message: 'Invalid credentials or account locked', 
        csrf_token: csrf_token 
      }
    end
  end
  
  get '/dashboard' do
    require_authentication!
    erb :dashboard
  end
  
  post '/logout' do
    logout!
    redirect '/login'
  end
  
  post '/users' do
    require_authentication!
    
    begin
      user = create_user(params[:username], params[:password])
      json id: user['id'], username: user['username']
    rescue => e
      status 400
      json error: e.message
    end
  end
end
```

### Classic Sinatra Style

```ruby
require 'sinatra'
require_relative 'SimpleSessionManager'

register Sinatra::SessionManager

configure do
  settings.session_config.session_secret = SecureRandom.hex(64)
  settings.session_config.users_store = 'users.json'
  settings.session_config.validate!
  
  use Rack::Session::Cookie,
      key: settings.session_config.cookie_name,
      secret: settings.session_config.session_secret,
      expire_after: settings.session_config.session_expire,
      httponly: true,
      secure: production?,
      same_site: :lax
end

# Routes here...
```

## API Reference

### `authenticated?`

Check if the current user is authenticated.

```ruby
get '/' do
  if authenticated?
    redirect '/dashboard'
  else
    redirect '/login'
  end
end
```

### `authenticate!(username, password)`

Authenticate a user with username and password. Returns `true` on success, `false` on failure.

```ruby
post '/login' do
  if authenticate!(params[:username], params[:password])
    redirect '/dashboard'
  else
    status 401
    'Invalid credentials'
  end
end
```

### `require_authentication!`

Require authentication for a route. Redirects to login page if not authenticated.

```ruby
get '/admin' do
  require_authentication!
  'Admin panel'
end
```

### `current_user`

Get the current authenticated user (without password hash).

```ruby
get '/profile' do
  require_authentication!
  user = current_user
  erb :profile, locals: { user: user }
end
```

### `logout!`

Clear the session and log out the user.

```ruby
post '/logout' do
  logout!
  redirect '/login'
end
```

### `create_user(username, password)`

Create a new user with validated password.

```ruby
post '/register' do
  begin
    user = create_user(params[:username], params[:password])
    'User created successfully'
  rescue => e
    status 400
    e.message
  end
end
```

### `csrf_token`

Get the current CSRF token for forms.

```ruby
<form method="post" action="/login">
  <input type="hidden" name="csrf_token" value="<%= csrf_token %>">
  <!-- form fields -->
</form>
```

### `verify_csrf_token!`

Automatically called before each request to verify CSRF tokens on non-GET requests.

## Security Features

### Password Requirements

- Minimum 12 characters (configurable)
- Must contain uppercase letter
- Must contain lowercase letter
- Must contain digit
- Must contain special character

### Account Lockout

After 5 failed login attempts (configurable), the account is locked for 15 minutes.

### Session Security

- Secure, httponly cookies
- Session rotation on login
- CSRF protection
- Configurable session expiration

### Thread Safety

The UserStore uses Monitor mixin for thread-safe file operations.

## Common Issues

### CSRF Token Mismatch

Ensure all forms include the CSRF token:

```erb
<% if csrf_token %>
  <input type="hidden" name="csrf_token" value="<%= csrf_token %>">
<% end %>
```

### Session Not Persisting

Check that:
- `SESSION_SECRET` is at least 64 characters
- Cookies are enabled in the browser
- Not using incognito/private browsing
- `secure: true` is not set in development (HTTP)

### User Creation Failing

Common password validation errors:
- "Password too short" - Needs 12+ characters
- "Password requires digit" - Add a number
- "Password requires uppercase" - Add an uppercase letter
- "Password requires lowercase" - Add a lowercase letter
- "Password requires special character" - Add !@#$%^&* etc.

### Classic vs Modular Sinatra

Classic style requires `settings.session_config`:
```ruby
settings.session_config.session_secret = '...'
```

Modular style uses `session_config` directly:
```ruby
session_config.session_secret = '...'
```