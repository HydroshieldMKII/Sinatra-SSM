# Sinatra SSM
 Simple Session Manager designed for Ruby Sinatra. It use a JSON file to authenticate users, and a cookie to store the session. It also allows to store generic data in the session cookie.

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
To configure the SimpleSessionManager, you must have a JSON file with at least the following structure:
```json
[
    {
        "username": "admin123",
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
    USERS_PATH =
    LOGIN_URL =
    LOG_PATH =
```
The values of the environment variables are as follows:
- COOKIE_NAME: The name of the cookie that will be used to store the session in the browser (eg. 'myapp.session').
- SESSION_KEY: The unique key that will be used to identify users in your json file (eg. 'username' like in my exmple or 'user_id').
- SESSION_SECRET: The secret key that will be used to encrypt the session. Must be at least 64 characters.
- SESSION_EXPIRE: The time in seconds that the session will last.
- SHA_KEY: The key that will be used to encrypt the passwords in the users.json file.
- USERS_PATH: Full path to the location of the users.json file with 'username' and 'password' keys.
- LOGIN_URL: Full path to the location of the login page (eg. '/login').
- LOG_PATH: Full path to the location of the log file.

## Usage
```ruby
    require 'sinatra'
    require_relative 'ssm'

    get '/home' do
        p isLoggedIn = protected! #=> Is logged in
        p haveColor = protected!('favorite_color') #=> Have a favorite color set in the cookie
    end

    post '/login' do #! Must contain username and password in basic auth request !#
        p isSuccess = login!('admin123') #=> Try to login, will set the value to 'admin123' set in the unique SESSION_KEY if successful
    end

    post '/logout' do
        logout! #=> Destroy the session key
    end

    post '/clear' do
        clear_session! #=> Clear all the session data
    end

    post '/save' do
        set_session_data!('favorite_color', 'red') #=> Save the color in the cookie
    end

    post '/retrieve' do
        p color = get_session_data!('favorite_color') #=> 'red'
    end

    get '/whoami' do
        user = whoami?#=> {username: '...', ...}
        p user.nil? ? 'Guest' : user.to_json
    end

    get '/public' do
        if authorized?
            p "Hi. I know you."
        else
            p "Hi. We haven't met. <a href='/login'>Login, please.</a>"
        end
    end

    get '/private' do
        authorize!
        p 'You are logged in!'
    end
```

## Functions

### `authorized?`
- Description: Check if the user is logged in.
- Returns: `true` if the user is logged in, otherwise `false`.

### `authorize!`
- Description: Redirects to the login page if the user is not logged in, otherwise do nothing.

### `protected!(key = SESSION_KEY)`
- Description: Return the authentication status of the user. Also can specify a key to check in the session.
- Parameters:
  - `request`: The request object containing authentication credentials or specified data.
  - `key`: The key to check in the session (defaults to `SESSION_KEY`).

### `login!(value = nil)`
- Description: Checks if a user is logged in and sets the session key if authentication is successful.
- Parameters:
  - `request`: The request object containing authentication credentials.
  - `value`: Optional value that must be included to set the session. Not required if the session key is already set.
- Returns: `true` if the user is successfully logged in, otherwise `false`.

### `logout!`
- Description: Remove the session key.

### `clearSession!`
- Description: Clear all the session data.

### `set_session_data!(key, value)`
- Description: Sets a value in the session using the provided key.
- Parameters:
  - `key`: The key under which to store the value.
  - `value`: Value to set in the session.

### `get_session_data!(key)`
- Description: Retrieves a value from the session using the provided key.
- Parameters:
  - `key`: The key of the value to retrieve.
- Returns: The value associated with the provided key in the session.

### `whoami?`
- Description: Retrieves the user object from the users file based on the session key. STRICT must be set to true.
- Returns: The user object corresponding to the `SESSION_KEY`.

### `add_user!(user_data)`
- Description: Add a user to the users file. Will encrypt the password using the SHA_KEY.
- Parameters:
    - `user`: A hash containing the user data. At least the `username` and `password` keys are required
- Returns: `true` if the user was successfully added, otherwise throw an error if couldnt read the file or user already exist.


## Common Errors
- The login doesnt work: Make sure that the `users.json` file is correctly configured and that the `SHA_KEY` is correct (must be the same key that was used to encrypt the current password). Also make sure that the request contains the username and password in the basic auth header.

- Variable not found in the .env file: Make sure that the .env file is correctly configured at the root of the project and that the environment variables are correctly set. Some of the variables are required for the correct operation of the SimpleSessionManager. Non required variables can be left empty and will have default value.

- The session is not being stored: Make sure that the that the `SESSION_SECRET` is correctly set. Also make sure that the `SESSION_EXPIRE` is correctly set. Using private browsing, incognito mode or clearing browser cache can also cause the session to not be stored.



    

