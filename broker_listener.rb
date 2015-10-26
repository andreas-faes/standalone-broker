require_relative 'internal_messages/internal_message_builder'

java_import 'be.mips.communication.endpoint.EndpointListener'
java_import 'be.mips.communication.internal.message.util.InternalMessageConverter'

#
# The BrokerListener class serves as the actual communication handler, and is an implementation of the Java
# EndpointListener interface for an Endpoint (used in the Broker class). It handles (and interprets) the incoming
# messages, and sends the correct responses to get the communication going. Creating objects is handled from within
# the Broker class, so do not use this directly.
class BrokerListener
  include EndpointListener

  #
  # Creates an instance of the BrokerListener class.
  #
  # @param broker [Broker] the broker object it is connected to
  def initialize(broker)
    $logger.debug("#{self} > initialized")
    @buffer = LepBuffer.new(8)
    @broker = broker
  end

  #
  # Implementation of the connected method. Does not really do anything for the moment.
  #
  # @param source [Endpoint] the endpoint the listener is connected to
  # @api private
  def connected(source)
    $logger.debug("#{self} > connected")
  end

  #
  # The dataReceived method is triggered every time a byte is sent over the network. The implementation
  # handles all these bytes, and stores them in a buffer until the message is complete. In that case, this
  # sequence of events is handled:
  #
  # * if the message is a 'Register' message, it sends an accept (and coerces the broker to send the interface message provided host & port)
  # * if the message is an 'Accept' message, it does nothing. It's just happy because the translator accepted his message and it cherishes that moment. I mean, it's the little things in life (like this) that a BrokerListener should appreciate and this instance sure knows how to appreciate a good Accept message.
  # * if the message is a 'Connected' message, it sends an 'Accept'. To reciprocate the favour for when the translator accepts. The BrokerListener is just this positive guy, you know.
  # * if the message is a 'Segmented' message, it stores the incoming (translated) message in the broker's in_queue and responds with the message in the out_queue.
  #
  # @param byte [Byte] incoming byte. Stored in a LepBuffer until the message is complete.
  # @param source [Endpoint] the endpoint the listener is connected to
  # @param channel [Channel] the communication channel from the incoming message. Reused for responding.
  # @api private
  def dataReceived(byte, source, channel)
    @buffer.write(byte)

    if @buffer.is_message_complete
      $logger.debug("IN: #{self} > received message from channel #{channel.channel_id}")
      $logger.debug("IN: #{self} > #{@buffer.message}")

      handle_register_message if @buffer.message.include?('Mnemonic=Register')

      if @buffer.message.include?('Mnemonic=Register') ||
          @buffer.message.include?('Mnemonic=Connected') ||
          @buffer.message.include?('Mnemonic=Unregister') ||
          @buffer.message.include?('Mnemonic=Idle')

        message = @broker.builder.build_accept_message

        $logger.debug("OUT: #{self} > #{InternalMessageConverter.message_to_url(message)}")
        source.write(message.as_url.to_java_bytes.to_java, channel)
      elsif @buffer.message.include?('Mnemonic=Convert')
        astm_message = AstmMessage.new(InternalMessageConverter.url_to_message(@buffer.message).segmented.segment_message)

        $logger.info("Broker in:")
        astm_message.all_segments.each { |segment|
          $logger.info("#{segment}")
        }
        @broker.in_queue.push(astm_message)

        out = @broker.next_outgoing_message
        $logger.info("Broker out:")
        out.all_segments.each { |segment|
          $logger.info("#{segment}")
        }

        message = @broker.builder.build_segmented_message(out)
        source.write(message.as_url.to_java_bytes.to_java, channel)
      end

      if @registered
        interface_message = @broker.build_interface_message

        @broker.send(interface_message)

        @registered = false
      end

      reset_buffer
    end
  end

  #
  # Implements the disconnected method for the EndpointListener interface.
  # Does not really do anything.
  #
  # @param source [Endpoint] the endpoint the listener is connected to
  # @api private
  def disconnected(source)
    $logger.debug("#{self} > disconnected")
  end

  #
  # Implements the channelClosed method for the EndpointListener interface.
  # Does not really do anything.
  #
  # @param source [Endpoint] the endpoint the listener is connected to
  # @param channel [Channel] the communication channel that was closed
  # @api private
  def channelClosed(source, channel)
    $logger.debug("#{self} > channel closed --> #{channel}")
  end

  #
  # Implements the channelOpened method for the EndpointListener interface.
  # Does not really do anything.
  #
  # @param source [Endpoint] the endpoint the listener is connected to
  # @param channel [Channel] the communication channel that was opened
  # @api private
  def channelOpened(source, channel)
    $logger.debug("#{self} > channel opened --> #{channel}")
  end

  #
  # Implements the endpointError method for the EndpointListener interface.
  # Does not really do anything.
  #
  # @param error_code [String] the error code
  # @param error_message [String] the error message
  # @param source [Endpoint] the endpoint the listener is connected to
  # @param channel [Channel] the communication channel
  #
  # @api private
  def endpointError(error_code, error_message, source, channel)
    $logger.fatal("#{self} > end point error")
    $logger.fatal("CODE > #{error_code}")
    $logger.fatal("MSG  > #{error_message}")
    $logger.fatal("SRC  > #{source}")
    $logger.fatal("CHAN > #{channel}")
  end

  private
  #
  # Resets the LepBuffer, so we can receive new messages (and do something with them)
  def reset_buffer
    @buffer = LepBuffer.new(8)
  end

  #
  # Sets the information for the outgoing connection towards the translator.
  #
  # @param incoming_message [Message] an incoming Register message from the translator
  def configure_interface(incoming_message)
    trl_interface_host = incoming_message.translator.application_interface.parameters.host
    trl_interface_port = incoming_message.translator.application_interface.parameters.port

    $logger.debug("#{self} setting interface for #{trl_interface_host}:#{trl_interface_port}")

    @broker.outgoing_host = trl_interface_host
    @broker.outgoing_port = trl_interface_port
  end

  #
  # Creates the broker's message builder, based on the Register message from the translator.
  #
  # @param incoming_message [Message] an incoming Register message from the translator
  def create_message_builder(incoming_message)
    @broker.target = incoming_message.source
    @broker.builder = InternalMessageBuilder.new(@broker.sender, @broker.target, @broker.application_name, @broker.application_version)
  end

  #
  # Handles the incoming Register message, and delegates to two other methods.
  def handle_register_message
    incoming_message = InternalMessageConverter.urlToMessage(@buffer.message)
    configure_interface(incoming_message)
    create_message_builder(incoming_message)

    @registered = true
  end
end