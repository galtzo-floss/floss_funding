module ActivationEventsHelper
  # Create a simple event with a minimal library double
  # Converts symbol state to string, since state is a string in the event
  def make_event(ns_name, state, library_name: nil, class_name: "Lib", key: "", config: {})
    config = FlossFunding::Configuration.new(config) if config.is_a?(Hash)
    lib = instance_double(class_name, :namespace => ns_name, :library_name => library_name.nil? ? nil : (library_name || ns_name.downcase), :config => config)
    FlossFunding::ActivationEvent.new(lib, key, state.to_s, nil)
  end
end
