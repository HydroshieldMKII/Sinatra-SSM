# Sinatra SSM
 A simple Session Manager designed for Ruby Sinatra

## Installation
```ruby
    cd ssm
    sudo bundle install
```

## Usage
```ruby
    require 'sinatra'
    require './ssm/SimpleSessionManager.rb'

    before do
        @ssm = SimpleSessionManager.new(session)
    end

    get '/home' do
        isLoggedIn = @ssm.protected!( _ , request) #=> Is logged in
        haveColor = @ssm.protected!( 'color' , request) #=> Have a color
    end

    post '/login' do #Must contain username and password in basic auth
        isSuccess = @ssm.setSession(request, 'username') 
    end

    post '/logout' do
        @ssm.destroySession
    end

    post '/save' do
        @ssm.setSessionData('favorite_color', 'red')
    end

    post '/retrieve' do
        color = @ssm.getSessionData('favorite_color') #=> 'red'
    end

    get '/whoami' do #Must have users data in a JSON file
        username = @ssm.getUser #=> {username: '...', ...}
    end
    
```
    

