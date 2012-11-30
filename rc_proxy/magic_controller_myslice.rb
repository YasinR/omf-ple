#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
require "xmlrpc/client"
require "pp"
$stdout.sync = true

NUM_OF_FACTORIES = 3

Blather.logger = logger

opts = {
  # XMPP server domain
  server: 'srv.mytestbed.net',
  # Debug mode of not
  debug: false
}

Logging.logger.root.level = :debug if opts[:debug]


# A factory for creating new magic api request instance (a resource)
module OmfRc::ResourceProxy::MagicFactory
  include OmfRc::ResourceProxyDSL

  register_proxy :magic_factory
end


module OmfRc::ResourceProxy::Magic
  include OmfRc::ResourceProxyDSL

  register_proxy :magic, :create_by => :magic_factory

  XMLRPC::Config.module_eval do
    remove_const :ENABLE_NIL_PARSER
    const_set :ENABLE_NIL_PARSER, true
  end

  property :auth_method
  property :username
  property :auth_string
  property :api_url

  # We want slice to be available for requesting 	
  request :slice do |resource|
    auth = {
      'AuthMethod' => resource.property.auth_method,
      'Username' => resource.property.username,
      'AuthString' => resource.property.auth_string
    }
    ret = XMLRPC::Client.new2(resource.property.api_url)
    # say params passed in is { slice_hrn: "ple.upmc.myslicedemo" }
    #key = params.keys.first
    begin
      pp ret.call("Get", auth, "slice",  [["slice_hrn",'=', "ple.upmc.myslicedemo"]],{}, ["slice_hrn"])
    rescue XMLRPC::FaultException => e
      raise RuntimeError, "Magic failed: #{e.faultCode} #{e.faultString}"
    end
  end
  
  # We want auth_method be available for configuring
  configure :auth_method do |magic, value|
    magic.property.auth_method = value
  end
  
  # We want username be available for configuring
  configure :username do |magic, value|
    magic.property.username = value
  end
  
  # We want auth_string be available for configuring
  configure :auth_string do |magic, value|
    magic.property.auth_string = value
  end
  
  # We want api_url be available for configuring
  configure :api_url do |magic, value|
    magic.property.api_url = value
  end

end


# In the factory script (like garage script)

#factory = OmfRc::ResourceFactory.new(:magic_factory, user: 'u', password: 'pw', uid: 'my_magic')
#factory.connect

EM.run do
  # Use resource factory method to initialise a new instance of factory
    factories = (1..NUM_OF_FACTORIES).map do |f|
    f = "factory_#{f}"
    info "Starting #{f}"
    factory = OmfRc::ResourceFactory.new(
      :magic_factory,
      opts.merge(user: f, password: 'pw', uid: f)
    )
    factory.connect
    factory
  end

  # Disconnect garage from XMPP server, when these two signals received
  trap(:INT) { factories.each(&:disconnect) }
  trap(:TERM) { factories.each(&:disconnect) }
end
