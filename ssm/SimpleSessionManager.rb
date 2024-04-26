require 'rack/session/cookie' #@session control
require 'dotenv/load' #load .env file
require "openssl" #for sha256
require 'logger' #for logging
require 'json' #for json parsing
    
#Session settings
COOKIE_NAME = ENV['COOKIE_NAME'] || "rack.@session" #Name of the session cookie in the browser
SESSION_KEY = ENV['SESSION_KEY'] || 'id' #Unique key to store in the session that identifies the user
SESSION_SECRET = ENV['SESSION_SECRET'] #At least 64 characters
SESSION_EXPIRE = ENV['SESSION_EXPIRE'] #In seconds

#Sha key for the password hashing
SHA_KEY = ENV['SHA_KEY'] #SHA key for password hashing

#Location of the users file
USERS_LOCATION = ENV['USERS_LOCATION'] #Expected to have 'username' and 'password' keys

#Setting up session
enable :sessions
use Rack::Session::Cookie,  :key => COOKIE_NAME,
                            :secret => SESSION_SECRET,
                            :expire_after => SESSION_EXPIRE

#STRICT = true
LOGGING = false
LOG_FILE = ENV['LOG_FILE'] #File to log to

class SimpleSessionManager
    def initialize(session)
        @session = session || raise("No session provided")

        #Verification of core settings
        SHA_KEY || raise("SHA_KEY not found in .env file")
        SESSION_SECRET || raise("SESSION_SECRET not found in .env file")
        SESSION_EXPIRE || raise("SESSION_EXPIRE not found in .env file")
        USERS_LOCATION || raise("USERS_LOCATION not found in .env file")

        #Setting up logging
        if LOGGING
            log_file = File.new(LOG_FILE, 'a+')
            log_file.sync = true
            $logger = Logger.new(log_file)
        end
    end

    #Return true if the user is successfuly logged in, false otherwise
    def setSession(request, value = nil)
        #no session, check for basic auth in the request
        if (@session[SESSION_KEY].nil?)
            raise "No request provided" if request.nil?
            raise "No value provided" if value.nil?

            #check if basic auth is provided
            auth = Rack::Auth::Basic::Request.new(request.env) 
            return false unless auth.provided? && auth.basic? && auth.credentials
        
            username, password = auth.credentials
            userInfo = authenticate(username, password)
        
            if userInfo.nil?
                log("Auth failed with username '#{username}'", "warn") if LOGGING
                return false
            end
        
            #Credentials are correct or user found, set @session
            log("Login success with username '#{username}'", "info") if LOGGING
            @session[SESSION_KEY] = value
        end
        return true
    end

    def destroySession
        @session.clear
    end

    #Sets a value in the session
    def setSessionData(key, value)
        raise "No key provided" if key.nil?
        raise "No value provided" if value.nil?
        @session[data] = value
    end

    #Returns a value in the session
    def getSessionData(key)
        return @session[key]
    end

    #Returns the user object from the users file with corresponding session key
    def whoami
        users = JSON.parse(File.read(USERS_LOCATION)) rescue raise "Unable to read users file or not JSON"
        return users.find { |user| user[SESSION_KEY] == @session[SESSION_KEY] }
    end

    #Halt the request if the user key is not set, session key by default
    def protected!(request = nil, key = SESSION_KEY)
        if data = SESSION_KEY
            return setSession(request)
        else
            return getSessionData(key) ? true : false
        end
    end

    private

    #Logs a message to the log file
    def log(message, type = "info")
        raise "Logging is not enabled" if !LOGGING
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
        users = JSON.parse(File.read(USERS_LOCATION))
        return users.find { |user| user['username'] == username && user['password'] == sha256(password)}
    end
end