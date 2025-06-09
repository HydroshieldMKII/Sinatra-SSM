require 'sinatra'
require_relative 'ssm/SimpleSessionManager'
require 'json'

register Sinatra::SessionManager

configure do
  set :views, File.dirname(__FILE__) + '/views'
  set :public_folder, File.dirname(__FILE__) + '/public'
  
  settings.session_config.session_secret = ENV['SESSION_SECRET'] || SecureRandom.hex(64)
  settings.session_config.users_store = ENV['USERS_PATH'] || 'users.json'
  settings.session_config.validate!
  
  use Rack::Session::Cookie,
      key: settings.session_config.cookie_name,
      secret: settings.session_config.session_secret,
      expire_after: settings.session_config.session_expire,
      httponly: true,
      secure: production?,
      same_site: :lax
  
  # Initialize default admin
  store_path = settings.session_config.users_store
  
  unless File.exist?(store_path) && File.size(store_path) > 2
    File.write(store_path, '[]')
    
    puts "Creating default admin user..."
    store = Sinatra::SessionManager::UserStore.new(store_path)
    store.create({
      username: 'admin',
      password_hash: BCrypt::Password.create('Admin123!@#$', cost: settings.session_config.bcrypt_cost)
    })
    puts "Default admin created (username: admin, password: Admin123!@#$)"
  end
end

get '/' do
  if authenticated?
    redirect '/dashboard'
  else
    redirect '/login'
  end
end

get '/login' do
  erb :login, locals: { csrf_token: csrf_token }
end

post '/login' do
  if authenticate!(params[:username], params[:password])
    redirect '/dashboard'
  else
    status 401
    erb :login, locals: { error_message: 'Invalid credentials or account locked', csrf_token: csrf_token }
  end
end

post '/logout' do
  logout!
  redirect '/login'
end

get '/dashboard' do
  require_authentication!
  erb :dashboard, layout: :layout
end

get '/users' do
  require_authentication!
  erb :users, layout: :layout
end

post '/users' do
  require_authentication!
  
  begin
    user = create_user(params[:username], params[:password])
    erb :users, layout: :layout, locals: {
      message: "User #{user['username']} created successfully",
      success: true
    }
  rescue => e
    status 400
    erb :users, layout: :layout, locals: {
      message: e.message,
      success: false
    }
  end
end