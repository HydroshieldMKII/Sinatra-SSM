require 'sinatra/base'
require 'rack/session/cookie'
require 'bcrypt'
require 'securerandom'
require 'json'
require 'fileutils'
require 'monitor'

module Sinatra
  module SessionManager
    class Config
      DEFAULTS = {
        cookie_name: 'session',
        session_key: 'user_id',
        session_expire: 86400,
        login_path: '/login',
        bcrypt_cost: 12,
        min_password_length: 12,
        max_failed_attempts: 5,
        lockout_duration: 900,
        session_rotation: true,
        csrf_protection: true
      }.freeze

      attr_accessor :cookie_name, :session_key, :session_secret, :session_expire,
                    :login_path, :users_store, :bcrypt_cost, :min_password_length,
                    :max_failed_attempts, :lockout_duration, :session_rotation,
                    :csrf_protection

      def initialize
        DEFAULTS.each { |k, v| send("#{k}=", v) }
      end

      def validate!
        raise "session_secret must be at least 64 characters" if session_secret.nil? || session_secret.length < 64
        raise "users_store not configured" if users_store.nil?
      end
    end

    class UserStore
      include MonitorMixin

      def initialize(path)
        super()
        @path = path
        @data = load_data
      end

      def find_by_username(username)
        synchronize { @data.find { |u| u['username'] == username } }
      end

      def find_by_id(id)
        synchronize { @data.find { |u| u['id'] == id } }
      end

      def create(attributes)
        synchronize do
          raise "Username exists" if find_by_username(attributes[:username])
          
          user = {
            'id' => SecureRandom.uuid,
            'username' => attributes[:username],
            'password_hash' => attributes[:password_hash],
            'created_at' => Time.now.to_i,
            'failed_attempts' => 0,
            'locked_until' => nil
          }
          
          @data << user
          save_data
          user
        end
      end

      def update(id, attributes)
        synchronize do
          user = @data.find { |u| u['id'] == id }
          raise "User not found" unless user
          
          attributes.each { |k, v| user[k.to_s] = v }
          save_data
          user
        end
      end

      private

      def load_data
        return [] unless File.exist?(@path)
        JSON.parse(File.read(@path))
      rescue JSON::ParserError
        raise "Invalid JSON in users file"
      end

      def save_data
        temp_path = "#{@path}.tmp"
        File.write(temp_path, JSON.pretty_generate(@data))
        FileUtils.mv(temp_path, @path)
      end
    end

    module Helpers
      def session_config
        @session_config ||= settings.session_config
      end

      def current_user
        return nil unless session[session_config.session_key]
        
        @current_user ||= begin
          store = UserStore.new(session_config.users_store)
          user = store.find_by_id(session[session_config.session_key])
          user&.reject { |k, _| k == 'password_hash' }
        end
      end

      def authenticated?
        !current_user.nil?
      end

      def authenticate!(username, password)
        store = UserStore.new(session_config.users_store)
        user = store.find_by_username(username)
        
        return false unless user
        
        # Check lockout
        if user['locked_until'] && user['locked_until'] > Time.now.to_i
          return false
        end
        
        # Verify password
        unless BCrypt::Password.new(user['password_hash']) == password
          # Update failed attempts
          failed_attempts = (user['failed_attempts'] || 0) + 1
          locked_until = failed_attempts >= session_config.max_failed_attempts ? 
                        Time.now.to_i + session_config.lockout_duration : nil
          
          store.update(user['id'], {
            failed_attempts: failed_attempts,
            locked_until: locked_until
          })
          
          return false
        end
        
        # Reset failed attempts on success
        store.update(user['id'], {
          failed_attempts: 0,
          locked_until: nil,
          last_login: Time.now.to_i
        })
        
        # Rotate session if configured
        session.clear if session_config.session_rotation
        
        session[session_config.session_key] = user['id']
        
        # Set CSRF token
        session[:csrf_token] = SecureRandom.hex(32) if session_config.csrf_protection
        
        true
      end

      def logout!
        session.clear
        @current_user = nil
      end

      def require_authentication!
        redirect session_config.login_path unless authenticated?
      end

      def csrf_token
        session[:csrf_token] ||= SecureRandom.hex(32) if session_config.csrf_protection
      end

      def verify_csrf_token!
        return unless session_config.csrf_protection
        return if request.get? || request.head? || request.options?
        
        token = params['csrf_token'] || env['HTTP_X_CSRF_TOKEN']
        halt 403, 'CSRF token mismatch' unless token == session[:csrf_token]
      end

      def create_user(username, password)
        validate_password!(password)
        
        store = UserStore.new(session_config.users_store)
        store.create({
          username: username,
          password_hash: BCrypt::Password.create(password, cost: session_config.bcrypt_cost)
        })
      end

      private

      def validate_password!(password)
        raise "Password too short" if password.length < session_config.min_password_length
        raise "Password requires digit" unless password =~ /\d/
        raise "Password requires uppercase" unless password =~ /[A-Z]/
        raise "Password requires lowercase" unless password =~ /[a-z]/
        raise "Password requires special character" unless password =~ /[^A-Za-z0-9]/
      end
    end

    def self.registered(app)
      app.set :session_config, Config.new
      
      app.helpers SessionManager::Helpers
      
      app.before do
        verify_csrf_token!
      end
    end
  end

  register SessionManager
end