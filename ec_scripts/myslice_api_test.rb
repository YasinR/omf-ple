# OMF_VERSIONS = 6.0
# This script will test the RC proxy developed for PLE API

@comm = OmfEc.comm

# @comm is default communicator defined in script runner
#
factory_id = "factory_1"
factory_topic = @comm.get_topic(factory_id)

factory_topic.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'FAILED' } do |message|
  logger.error message
end

msgs = {
  create: @comm.create_message([type: 'magic']),
  #request: @comm.request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power]),
  #request_api_url: @comm.request_message([:api_url]),
  set_auth_method: @comm.configure_message([auth_method: "password"]),
  set_username: @comm.configure_message([username: "demo"]),
  set_auth_string: @comm.configure_message([auth_string: "demo"]),
  set_api_url: @comm.configure_message([api_url: "http://demo.myslice.info:7080/"]),
  request: @comm.request_message([:slice]),
}


msgs[:create].on_inform_failed do |message|
  logger.error "Resource creation failed ---"
  logger.error message.read_content("reason")
end


msgs[:request].on_inform_failed do |message|
  logger.error message.read_content("reason")
end


# Triggered when new messages published to the topics I subscribed to
msgs[:create].on_inform_created do |message|
  magic_topic = @comm.get_topic(message.resource_id)
  magic_id = magic_topic.id

  msgs[:release] ||= @comm.release_message { |m| m.element('resource_id', magic_id) }

  msgs[:release].on_inform_released  do |message|
    logger.info "Magic (#{message.resource_id}) turned off (resource released)"
    done!
  end

  logger.info "Magic #{magic_id} ready for testing"

  magic_topic.subscribe do
    # Now subscribed to engine topic, we can ask for some information about the engine
    # msgs[:request].publish magic_id

    # We will set the auth method
    msgs[:set_auth_method].publish magic_id

    # Now we will set username
    msgs[:set_username].publish magic_id
    
    # Now we will set password
    msgs[:set_auth_string].publish magic_id
    
    # Now we will set api url
    msgs[:set_api_url].publish magic_id

	# Now we request the api output
    msgs[:request].publish magic_id


    #@comm.add_timer(5) do
      # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
     # msgs[:reduce_throttle].publish engine_id

      # Testing error handling
      #msgs[:test_error_handling].publish magic_id
    #end

    # 10 seconds later, we will 'release' this engine, i.e. shut it down
    @comm.add_timer(10) do
      msgs[:release].publish factory_id
    end
  end
end

factory_topic.subscribe do
  # If subscribed, we publish a 'create' message, 'create' a new engine for testing
  msgs[:create].publish factory_topic.id
end
