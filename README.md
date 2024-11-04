# Sinatra SSM

Session Storage Manager is a tool designed for Ruby Sinatra. It use a JSON file to authenticate users, and a cookie to store the session. It also allows to store generic data in the session cookie.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Functions](#functions)
  - [authorized?](#authorized)
  - [authorize!](#authorize)
  - [protected!](#protected)
  - [login!](#login)
  - [logout!](#logout)
  - [clear_session!](#clear_session)
  - [set_session_data!](#set_session_data)
  - [get_session_data!](#get_session_data)
  - [whoami?](#whoami)
  - [add_user!](#add_user)
- [Common Errors](#common-errors)

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

You must have a JSON file with at least the following structure for your users:

```json
[
  {
    "username": "admin123",
    "password": "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",
    "my_session_key": "j7Bb9" //optional if you use 'username' as session key
  },
  {
    "username": "user",
    "password": "04f8996da763b7a969b1028ee3007569eaf3a635486ddab211d512c85b9df8fb",
    "my_session_key": "4uTN4" //optional if you use 'username' as session key
  }
]
```

You must also configure the .env file with the preloaded environment variables:

```env
    COOKIE_NAME =
    SESSION_KEY =
    SESSION_SECRET =
    SESSION_EXPIRE =
    LOGIN_PATH =
    USERS_PATH =
    LOG_PATH =
    SHA_KEY =
    STRICT_PASSWORD =
    PWD_MIN_PASSWORD_LENGTH =
    PWD_MIN_SPECIAL_CHARS =
    PWD_MIN_NUMBERS =
```

The values of the environment variables are as follows:

- COOKIE_NAME: The name of the cookie that will be used to store the session in the browser (eg. 'myapp.session').

- SESSION_KEY: The unique key that will be used to identify users in your json file (eg. 'username', 'session_key', 'user_id', etc).

- SESSION_SECRET: The secret key that will be used to encrypt the session. Must be at least 64 characters.

- SESSION_EXPIRE: The time in seconds that the session will last.

- LOGIN_PATH: Full path to the location of the login page (eg. '/login').

- USERS_PATH: Full path to the location of the users.json file with 'username' and 'password' keys.

- LOG_PATH: Full path to the location of the log file.

- SHA_KEY: The key that will be used to encrypt the passwords in the users.json file.

- STRICT_PASSWORD: If true, will use bcrpyt instead of sha256 for the password hashing. It will also require the password to have at least PWD_MIN_PASSWORD_LENGTH characters, PWD_MIN_SPECIAL_CHARS special characters and PWD_MIN_NUMBERS numbers.

- PWD_MIN_PASSWORD_LENGTH: The minimum length of the password.

- PWD_MIN_SPECIAL_CHARS: The minimum number of special characters in the password.

- PWD_MIN_NUMBERS: The minimum number of numbers in the password.

## Usage

```ruby
    require 'sinatra'
    require_relative 'ssm'

    get '/home' do
        is_logged_in = protected! #=> Is logged in
        have_color = protected!('favorite_color') #=> Have a favorite color set in the cookie
    end

    post '/login' do #! Must contain username and password in basic auth request !#
        is_success = login!('j7Bb9') #=> Set unique identifier for the session. Must be unique for each user!
    end

    post '/logout' do
        logout! #=> Destroy the session key (logout)
    end

    post '/clear' do
        clear_session! #=> Clear all the session data (logout + remove all session data)
    end

    post '/save' do
        set_session_data!('favorite_color', 'red') #=> Save the color in the cookie
    end

    post '/retrieve' do
        color = get_session_data!('favorite_color') #=> 'red'
    end

    get '/whoami' do
        user = whoami? #=> {username: '...', ...}
        user.nil? ? 'Guest' : user.to_json
    end

    post '/adduser' do
        user = {'username': "joel", 'password': "Qwerty123@!"}
        is_success = add_user!(user) #=> Add a user to the database and encrypt the password
    end

    get '/public' do
        if authorized?
            "Hi. I know you."
        else
            "Hi. We haven't met. <a href='/login'>Login, please.</a>"
        end
    end

    get '/private' do
        authorize! # Redirect to login if not logged in
        'You are logged in!'
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
  - `key`: The key to check in the session (defaults to `SESSION_KEY`).

### `login!(value = nil)`

- Description: Checks if a user is logged in and sets the session key if authentication is successful.
- Parameters:
  - `value`: Optional value that must be included to set the session. Not required if the session key is already set.
- Returns: `true` if the user is successfully logged in, otherwise `false`.

### `logout!`

- Description: Remove the session key.

### `clear_session!`

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
- Returns: The user object corresponding to the `SESSION_KEY` in users.json, otherwise `nil`

### `add_user!(user_data)`

- Description: Add a user to the users file. Will encrypt the password using the `STRICT_PASSWORD` method.
- Parameters:
  - `user_data`: A hash containing the user data. At least the `username` and `password` keys are required
- Returns: `true` if the user was successfully added, otherwise throw an error if couldnt read the file or user already exist.

## Common Errors

- The login doesnt work: Make sure that the `users.json` file is correctly configured and that the `SHA_KEY` is correct (must be the same key that was used to encrypt the current password) if you dont use `STRICT_PASSWORD`. Also make sure that the request contains the username and password in the basic auth header.

- Variable not found in the .env file: Make sure that the .env file is correctly configured at the root of the project and that the environment variables are correctly set. Some of the variables are required for the correct operation of the Session Storage Manager. Non required variables can be left empty and will have default value.

- The session is not being stored: Make sure that the that the `SESSION_SECRET` is correctly set. Also make sure that the `SESSION_EXPIRE` is correctly set. Using private browsing, incognito mode or clearing browser cache can also cause the session to not be stored or cleared.
