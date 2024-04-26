# Sinatra SSM
 Simple Session Manager is designed for Ruby Sinatra. It use a JSON file to authenticate users, and a cookie to store the session. It also allows to store data in the session cookie.

## Installation
Clone the repository
```
    git clone https://github.com/HydroshieldMKII/Sinatra-SSM.git
```
Enter the directory
```bash
    cd ssm
```
Install the bundler gem and the dependencies
```bash
    sudo gem install bundler
```
```bash
    sudo bundle install
```

## Configuration
To configure the SimpleSessionManager, you must have a JSON file with the following structure:
```json
[
    {
        "username": "admin",
        "password": "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918"
    },
    {
        "username": "user",
        "password": "04f8996da763b7a969b1028ee3007569eaf3a635486ddab211d512c85b9df8fb"
    }
]
```
You must also configure the .env file with the preloaded environment variables:
```env
    COOKIE_NAME = 
    SESSION_KEY = 
    SESSION_SECRET = 
    SESSION_EXPIRE = 
    SHA_KEY = 
    USERS_LOCATION =
```
The values of the environment variables are as follows:
- COOKIE_NAME: The name of the cookie that will be used to store the session in the browser (eg. 'myapp.session').
- SESSION_KEY: The unique key that will be used to identify users (eg. 'username' or 'user_id').
- SESSION_SECRET: The secret key that will be used to encrypt the session. Must be at least 64 characters.
- SESSION_EXPIRE: The time in seconds that the session will last.
- SHA_KEY: The key that will be used to encrypt the passwords in the users.json file.
- USERS_LOCATION: Full path to the location of the users.json file.



## Usage
```ruby
    require 'sinatra'
    require './ssm/SimpleSessionManager.rb'

    before do
        @ssm = SimpleSessionManager.new(session)
    end

    get '/home' do
        isLoggedIn = @ssm.protected!(request) #=> Is logged in
        haveColor = @ssm.protected!( _ , 'color') #=> Have a color
    end

    post '/login' do #Must contain username and password in basic auth
        isSuccess = @ssm.setSession(request, 'theUsername123') 
    end

    post '/logout' do
        @ssm.destroySession #=> Destroy the session
    end

    post '/save' do
        @ssm.setSessionData('favorite_color', 'red') #=> Save the color in the cookie
    end

    post '/retrieve' do
        color = @ssm.getSessionData('favorite_color') #=> 'red'
    end

    get '/whoami' do #Must have users data in a JSON file
        username = @ssm.getUser #=> {username: '...', ...}
    end
    
```
    

