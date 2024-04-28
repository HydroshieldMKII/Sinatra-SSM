require 'sinatra/base'
require 'rack/session/cookie' #Session control
require 'dotenv/load' #Load .env file
require "openssl" #For sha256
require 'logger' #For logging
require 'json' #For json parsing
    
#Session settings
COOKIE_NAME = ENV['COOKIE_NAME'] || "rack.session" #Name of the session cookie in the browser
SESSION_KEY = ENV['SESSION_KEY'] || "username" #Unique key to store in the session that identifies the user
SESSION_SECRET = ENV['SESSION_SECRET'] #At least 64 characters
SESSION_EXPIRE = ENV['SESSION_EXPIRE'].to_i #In seconds

#Sha key for the password hashing
SHA_KEY = ENV['SHA_KEY'] #SHA key for password hashing

#Login settings
LOGIN_URL = ENV['LOGIN_PATH'] || "/login" #Path to the login page

#Location of the users file
USERS_LOCATION = ENV['USERS_PATH'] #Expected to have 'username' and 'password' keys in json format

#Setting up session
use Rack::Session::Cookie,  :key => COOKIE_NAME,
                            :secret => SESSION_SECRET,
                            :expire_after => SESSION_EXPIRE

#Logging settings
LOGGING = false
LOG_FILE = ENV['LOG_PATH'] #Path to the log file

module Sinatra
  module SSM
    module Helpers
        def authorized?
            return session[SESSION_KEY] ? true : false
        end

        def authorize!
            redirect LOGIN_URL, 302 unless authorized?
        end

        def protected!(key = SESSION_KEY)
            if key == SESSION_KEY
                return authorized? #=> true or false
            else
                return getSessionData!(key) ? true : false
            end
        end

        def login!(value)
            return true unless session[SESSION_KEY].nil?

            raise "No value provided to set session" if value.nil?

            #check if basic auth is provided
            auth = Rack::Auth::Basic::Request.new(request.env) 
            return false unless auth.provided? && auth.basic? && auth.credentials

            #Check if the credentials match
            username, password = auth.credentials
            userInfo = authenticate(username, password)

            #Credentials are incorrect
            if userInfo.nil?
                log("Auth failed with username '#{username}'", "warn") if LOGGING
                return false
            end

            #Credentials are correct, set session
            log("Login success with username '#{username}'", "info") if LOGGING
            session[SESSION_KEY] = value
            return true
        end

        def logout!
            session[SESSION_KEY] = nil
        end

        def clear_session!
            session.clear
        end

        def set_session_data!(key, value)
            raise "No key provided" if key.nil?
            raise "No value provided" if value.nil?
            session[key] = value
        end

        def get_session_data!(key)
            return session[key]
        end

        def whoami?
            return nil if session[SESSION_KEY].nil?
            begin
                users = JSON.parse(File.read(USERS_LOCATION)) 
                return users.find { |user| user[SESSION_KEY] == session[SESSION_KEY] }.except('password')
            rescue Exception => e
                raise e
            end
        end

        def add_user!(user_data)
            raise "No data provided" if user_data.nil?
            raise "The data provided is not a hash" unless user_data.is_a? Hash
            raise "No username provided" if user_data['username'].nil?
            raise "No password provided" if user_data['password'].nil?

            begin
                #Check if the user already exists
                users = JSON.parse(File.read(USERS_LOCATION))
                raise "A user with the same username already exists" if users.find { |user| user['username'] == user_data['username'] }

                #Change the password to sha256
                user_data['password'] = sha256(user_data['password'])
        
                users << user_data
                File.write(USERS_LOCATION, users.to_json)
                return true
            rescue Exception => e
                raise e
            end
        end

        private

        #Logs a message to the log file
        def log(message, type = "info")
            $logger.warn(message) if type == "warn"
            $logger.info(message) if type == "info"
        end

        #Hashes a string using sha256
        def sha256(value)
            nil if value.nil? || value.empty?
            OpenSSL::HMAC.hexdigest("sha256", SHA_KEY, value)
        end

        # Returns corresponding user if username and password are correct
        def authenticate(username, password)
            begin
                users = JSON.parse(File.read(USERS_LOCATION))
                return users.find { |user| user['username'] == username && user['password'] == sha256(password)}
            rescue Exception => e
                raise e
            end
        end
    end

    def self.registered(app)
        app.helpers SSM::Helpers

        #Verification of core settings
        SHA_KEY || raise("SHA_KEY not found in .env file")
        SESSION_SECRET || raise("SESSION_SECRET not found in .env file")
        SESSION_EXPIRE || raise("SESSION_EXPIRE not found in .env file")
        USERS_LOCATION || raise("USERS_LOCATION not found in .env file")

        #Check if the users file exists and it's json
        begin
            raise "Users file not found at '#{USERS_LOCATION}'" unless File.exist?(USERS_LOCATION)
            JSON.parse(File.read(USERS_LOCATION))
        rescue Exception => e
            raise e
        end

        #Setting up logging
        if LOGGING
            LOG_FILE || raise("LOG_PATH not found in .env file")
            log_file = File.new(LOG_FILE, 'a+')
            log_file.sync = true
            $logger = Logger.new(log_file)
        end
    end
  end

  register SSM
end