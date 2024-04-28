require 'sinatra/base'
require 'rack/session/cookie' #Session control
require 'dotenv/load' #Load .env file
require 'bcrypt' #For advanced password hashing
require "openssl" #For sha256
require 'logger' #For logging
require 'json' #For json parsing
    
#Session settings
COOKIE_NAME = ENV['COOKIE_NAME'] || "rack.session" #Name of the session cookie in the browser
SESSION_KEY = ENV['SESSION_KEY'] || "username" #Unique key to store in the session that identifies the user
SESSION_SECRET = ENV['SESSION_SECRET'] #At least 64 characters
SESSION_EXPIRE = ENV['SESSION_EXPIRE'].to_i || 259200 #In seconds

#Strict password settings
STRICT_PASSWORD = ENV['STRICT_PASSWORD'] || false #Use bcrypt for password hashing, with strict password requirements
PWD_MIN_PASSWORD_LENGTH = ENV['PWD_MIN_PASSWORD_LENGTH'].to_i || 8 #Minimum password length
PWD_MIN_SPECIAL_CHARS = ENV['PWD_MIN_SPECIAL_CHARS'].to_i || 1 #Minimum special characters
PWD_MIN_NUMBERS = ENV['PWD_MIN_NUMBERS'].to_i || 1 #Minimum numbers

#SHA settings
SHA_KEY = ENV['SHA_KEY'] #Secret key for sha256 hashing your passwords

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
LOG_FILE = ENV['LOG_PATH'] || "log.txt" #Path to the log file

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

            #Check if the credentials are correct
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

        def add_user!(user_data) #=> { 'username' => '...', 'password' => '...' }
            raise "No data provided" if user_data.nil?
            raise "The data provided is not a hash" unless user_data.is_a? Hash
            raise "No #{SESSION_KEY} provided" if user_data[SESSION_KEY].nil?
            raise "No username provided" if user_data[:username].nil?
            raise "No password provided" if user_data[:password].nil?

            username = user_data[:username] 
            password = user_data[:password]

            begin
                users = JSON.parse(File.read(USERS_LOCATION))
                raise "Username already exists" if users.find { |user| user['username'] == username }

                if STRICT_PASSWORD
                    raise "Password does not meet the requirements" unless password.length >= PWD_MIN_PASSWORD_LENGTH
                    raise "Password does not meet the requirements" unless password.count("0-9") >= PWD_MIN_NUMBERS
                    raise "Password does not meet the requirements" unless password.count("!@#$%^&*") >= PWD_MIN_SPECIAL_CHARS
                    s_password = bcrypt_hash(password)
                else
                    s_password = sha256(password)
                end

                user_data[:password] = s_password

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

        # Hashes a string using bcrypt
        def bcrypt_hash(password)
            BCrypt::Password.create(password)
        end

        # Verifies a password against a bcrypt hash
        def bcrypt_verify(password, hash)
            BCrypt::Password.new(hash) == password
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
                if STRICT_PASSWORD
                    return users.find { |user| user['username'] == username && bcrypt_verify(password, user['password']) }
                else
                    return users.find { |user| user['username'] == username && user['password'] == sha256(password)}
                end
            rescue Exception => e
                raise e
            end
        end
    end

    def self.registered(app)
        app.helpers SSM::Helpers

        #Verification of core settings
        if STRICT_PASSWORD
            PWD_MIN_PASSWORD_LENGTH || raise("PWD_MIN_PASSWORD_LENGTH not defined")
            PWD_MIN_SPECIAL_CHARS || raise("PWD_MIN_SPECIAL_CHARS not defined")
            PWD_MIN_NUMBERS || raise("PWD_MIN_NUMBERSnot defined")
        else
            SHA_KEY || raise("SHA_KEY not defined")
        end

        SESSION_KEY || raise("SESSION_KEY not defined")
        COOKIE_NAME || raise("COOKIE_NAME not defined")
        SESSION_SECRET || raise("SESSION_SECRET not defined")
        SESSION_EXPIRE || raise("SESSION_EXPIRE not defined")
        LOGIN_URL || raise("LOGIN_PATH not defined")



        #Check if the users file exists and it's json
        begin
            raise "Users file not found at '#{USERS_LOCATION}'" unless File.exist?(USERS_LOCATION)
            JSON.parse(File.read(USERS_LOCATION)) #Check if the file is json
        rescue Exception => e
            raise e
        end

        #Setting up logging
        if LOGGING
            LOG_FILE || raise("LOG_PATH not defined")
            log_file = File.new(LOG_FILE, 'a+')
            log_file.sync = true
            $logger = Logger.new(log_file)
        end
    end
  end

  register SSM
end