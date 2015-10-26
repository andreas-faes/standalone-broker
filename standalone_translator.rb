#
# The StandaloneTranslator class serves as the entry point for all standalone translator testing. It
# manages the translator connection (options) and starts its own broker.
#
# @example
#   translator = StandaloneTranslator.new('TRND', '-s 8999 -x TrinidadSystem')
#   translator.debug_setting = 2
#   translator.logfile_path = 'C:\test_results\TRND'
#   translator.start
#   # do some tests here
#   translator.stop
#
# @attr_reader [Broker] broker the application broker, started by the object
# @attr [String] translator_name the translator name, important for starting the correct driver
# @attr [String] executable_path the path to the executable. Defaults to C:\temp\<translator_name>.exe
# @attr [Fixnum] debug_setting the debug setting (-D parameter). Defaults to 3
# @attr [String] logfile_path the base path for the logging (-L parameter). Defaults to C:\temp\<translator_name>\
# @attr [Fixnum] broker_port the port for the broker (-S parameter). Defaults to 3000.
# @attr [String] options the specific options for the translator under test
class StandaloneTranslator
  attr_accessor :executable_path
  attr_accessor :logfile_path
  attr_accessor :debug_setting
  attr_accessor :broker_port
  attr_accessor :translator_name
  attr_accessor :options
  attr_reader :broker

  #
  # Creates a new StandaloneTranslator connection with the given name and options. The presence/absence
  # of the -s parameter in the options determines whether or not the translator will act as client or server
  # (and not the presence of the external_interface parameter).
  #
  # To avoid confusion, set the external_interface parameter to nil if option -s is used.
  #
  # @example
  #   # the instrument can connect to the translator running as server
  #   trnd_as_server = StandaloneTranslator.new('TRND', '-s 8999 -q -x TrinidadSystem', nil)
  #   # the translator connects to the instrument acting as server
  #   trnd_as_client = StandaloneTranslator.new('TRND', '-q -x TrinidadSystem')
  #
  # @param translator_name [String] the name of the translator. Used in the outgoing communication.
  # @param [Hash] application_info the application info, defaults to CENTRALINK v.15.0.4
  # @option application_info [String] :sender the application sender
  # @option application_info [String] :name the application name
  # @option application_info [String] :version the application version
  # @param [Hash] external_interface the external interface towards the instrument connection, defaults to 127.0.0.1:9999 with a timeout of 5
  # @option external_interface [String] :host the hostname
  # @option external_interface [Fixnum] :port the port
  # @option external_interface [Fixnum] :timeout the timeout
  # @param options [String] the options for the translator under test, does not include the generic options.
  def initialize(translator_name,
                 options = nil,
                 external_interface = {:host => '127.0.0.1', :port => 9999, :timeout => 5},
                 application_info = {:sender => 'CENTRALINK', :name => 'CENTRALINK', :version => '15.0.4'})
    @translator_name = translator_name
    @executable_path = "C:\\temp\\#{@translator_name}.exe"
    @logfile_path = "C:\\temp\\#{@translator_name}"
    @broker_port = 3000
    @debug_setting = 3
    @options = options
    @application_info = application_info
    @external_interface = external_interface

    if options.include?('-s') && !external_interface.nil?
      $logger.error("#{self} > Constructor with inconsistent interface settings (-s & external interface defined).")
      # to fix, either remove the -s parameter or use nil as the third parameter in this constructor (instead of the default)
    end
  end

  #
  # Starts the standalone translator connection, using the configured options.
  def start
    generic_start_options = generic_options
    $logger.info("#{self} > Starting standalone translator with following properties:")
    $logger.info("#{self} > Name: #{@translator_name} (path: #{@executable_path})")
    $logger.info("#{self} > Generic options: #{generic_start_options}")
    $logger.info("#{self} > Specific translator options: #{@options}")
    $logger.info("#{self} > Broker setup: #{@application_info[:sender]} (#{@application_info[:name]} v.#{@application_info[:version]})")

    # assemble the options string
    startup_string = "#{@executable_path} #{generic_start_options} #{@options}"

    # make sure the logging folder (else, create it):
    Dir.mkdir(@logfile_path) unless File.exists?(@logfile_path)

    # create the broker & start it
    @broker = Broker.new(@broker_port, @application_info[:sender], @application_info[:name], @application_info[:version])
    @broker.external_interface = @external_interface unless is_server

    @broker.start

    # check if the executable exists
    # check if options nil --> in dat geval moet er een external connection stuff ding zijn, nee? Misschien ook defaults voor voorzien dan
    @process = IO.popen(startup_string)
  end

  #
  # Stops the standalone translator instance.
  def stop
    # first lets the broker send the stop message (and initiate the shutdown)
    # then disconnects all endpoints
    @broker.stop
  end

  #
  # Returns whether or not the translator under test will act as a server or as a client (external connection).
  # This is derived from the presence of the '-s' parameter in the options string.
  #
  # The outcome of this parameter determines what messages the broker will send towards the translator.
  #
  # @example
  #   trl = StandaloneTranslator.new('trnd','-s 8000')
  #   expect(trl.is_server).to be_truthy
  #   trl2 = StandaloneTranslator.new('trnd','')
  #   expect(trl2.is_server).to be_falsey
  #
  # @return [Boolean] whether or not the translator acts as a server
  def is_server
    @options.include?('-s')
  end

  private
  def generic_options
    "-S #{@broker_port.to_s} -D #{@debug_setting.to_s} -L #{@logfile_path}\\#{@translator_name}_standalone.log"
  end
end