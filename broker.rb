require_relative 'broker_listener'
java_import 'be.mips.communication.endpoint.ServerSocketEndpoint'
java_import 'be.mips.communication.endpoint.SocketEndpoint'
java_import 'be.mips.communication.endpoint.Channel'

#
# The Broker class is an abstraction of an internal service as available from
# GLIMS or CENTRALINK. It provides the functionality to start the communication (handshaking)
# between a real translator instance and this broker.
#
# All communication from the point of startup on, is controlled through two seperate queues, which
# hold the outgoing ASTM message in the internal protocol and store the incoming ASTM messages for
# verification purposes.
#
# @example
#   broker = Broker.new(3000, 'CENTRALINK', 'CENTRALINK', '15.0.4')
#   broker.start
#   broker.out_queue.push(work_order_message) # an ASTM message in the SampleNet internal format, this is usually a work order
#
#   # do the actual testing using the translator connection here
#   work_order = some_translator.send [q]
#
#   # then check the outcome
#   translated_message = broker.in_queue.pop # AstmMessage object
#   expect(translated_message.str_segment_order).to eq('HPOL')
#   expect(translated_message.patient_segments[0].P_6_1_1).to eq('Foernooh')
#
#
# @attr_reader [String] sender the application sender (e.g. CENTRALINK, GLIMS). Set in the constructor.
# @attr_reader [String] application_name the application name, usually the same as the sender. Set in the constructor.
# @attr_reader [String] application_version the application version (e.g. '15.0.4'). Set in the constructor.
# @attr_reader [BrokerQueue] in_queue the queue of all received translations (from the translator)
# @attr_reader [BrokerQueue] out_queue the queue of all outgoing ASTM messages (towards the translator)
# @attr [String] external_interface the external interface for the instrument connection.
# @attr [String] target the target for the outgoing communication, i.e. the translator name
# @attr [InternalMessageBuilder] builder the builder object for messages in the URL format
# @attr [String] outgoing_host the hostname for the translator, determined by the translator through an
#                         incoming Register message
# @attr [String] outgoing_port the port for the translator, determined by the translator through an
#                         incoming Register message
class Broker
  attr_reader :sender
  attr_reader :application_name
  attr_reader :application_version
  attr_reader :in_queue
  attr_reader :out_queue

  attr_accessor :external_interface
  attr_accessor :target
  attr_accessor :builder
  attr_accessor :outgoing_host
  attr_accessor :outgoing_port

  #
  # Creates a new Broker instance with a listen port, sender name (the application we are mocking)
  # and application name and version.
  #
  # @param port [Fixnum] the listen port for the broker, should correspond to the port the translator connects to
  # @param sender [String] the application sender (e.g. CENTRALINK, GLIMS).
  # @param application_name [String] the application name, usually the same as the sender.
  # @param application_version [String] the application version (e.g. '15.0.4')
  def initialize(port, sender, application_name, application_version)
    @sender = sender
    @application_name = application_name
    @application_version = application_version

    @incoming_socket = ServerSocketEndpoint.new(port)
    @listener = BrokerListener.new(self)
    @incoming_socket.add_endpoint_listener(@listener)

    @in_queue = BrokerQueue.new(@sender)
    @out_queue = BrokerQueue.new(@sender)
  end

  #
  # Starts the broker, and waits for an incoming connection from the translator.
  #
  # Always start the broker before starting the translator.
  def start
    @incoming_socket.connect
  end

  #
  # Stops the broker.
  def stop
    $logger.debug("#{self} > stopping the translator by sending STOP message")
    stop_message = @builder.build_stop_message
    send(stop_message)

    # sleep(1)
    # disconnect the sockets
    $logger.debug("#{self} > disconnecting incoming socket")
    @incoming_socket.disconnect
    $logger.debug("#{self} > disconnecting outgoing socket")
    @outgoing_socket.disconnect
    $logger.debug("#{self} > disconnected")
  end

  #
  # Sends an outgoing message to the running translator. Is only possible when the
  # broker and the translator have successfully connected.
  #
  # Avoid using this method directly, and approach it through the out_queue which handles the
  # outgoing messages towards the translator.
  #
  # @param message [Message] a segmented message
  # @api private
  def send(message)
    raise 'Outgoing host unknown' if @outgoing_host.nil?
    raise 'Outgoing port unknown' if @outgoing_port.nil?

    $logger.debug("OUT: #{self} > #{InternalMessageConverter.message_to_url(message)}")
    @outgoing_channel = Channel.new
    @outgoing_socket = SocketEndpoint.new(@outgoing_host, @outgoing_port.to_i)
    @outgoing_socket.add_endpoint_listener(BrokerListener.new(self))
    @outgoing_socket.connect
    @outgoing_socket.open_channel(@outgoing_channel)
    @outgoing_socket.write(message.as_url.to_java_bytes.to_java, @outgoing_channel)
  end

  #
  # Returns the next outgoing message towards the translator. Raises an exception
  # when no message is queued.
  #
  # @api private
  def next_outgoing_message
    raise 'No outgoing ASTM message in queue' if @out_queue.peek.nil?

    @out_queue.pop
  end


  def build_interface_message
    if @external_interface.nil?
      $logger.debug("#{self} > building interface message")
      @builder.build_interface_message
    else
      $logger.debug("#{self} > building external interface message")
      @builder.build_external_interface_message(@external_interface)
    end
  end
end