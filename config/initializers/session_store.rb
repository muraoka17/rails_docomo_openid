# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_docomo_openid_session',
  :secret      => '4c89038c9c42aff1f5183cafa3245041dd3a1e3b3d192bdeb099509f21be2a7ebe61bdcced676b6efee466c083a10cf09bfe3c64c76b9ef5b2cedd9c0a103e0b'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
