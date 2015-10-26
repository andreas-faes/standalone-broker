#
# The BrokerQueue is a simple queuing implementation, specifically for use with a Broker
# class. It provides a stack like interface based on the FIFO principle (not FILO, like a true stack),
# and serves as a creation point for AstmMessages at runtime to support the test syntax.
class BrokerQueue
  #
  # Constructor. Creates a new BrokerQueue with no AstmMessages preloaded.
  #
  # @param sender [String] the application sender when AstmMessages need to be constructed using the
  #   push functionality. Defaults to nil.
  def initialize(sender = nil)
    @sender = sender
    @store = []
  end

  #
  # Push an AstmMessage to the queue. If the object is an array of AstmSegments, it constructs
  # an AstmMessage and then pushes it to the queue. In all other cases, it raises an exception.
  #
  # @param object [AstmMessage, Array<AstmSegment>] an AstmMessage or an array of AstmSegments
  def push(object)
    if object.is_a?(Array) # expects an array of ASTM segments.
      @store.push AstmMessageBuilder.build(@sender, object, false)
    elsif object.is_a?(AstmMessage)
      @store.push object
    else
      raise 'Cannot push this object to the queue'
    end
  end

  #
  # Returns the first element in the queue, without removing it from the queue. See the
  # difference with {#pop} to determine which to use.
  #
  # @example
  #   size_before_peek = queue.size
  #   message_1 = queue.peek
  #   message_2 = queue.peek
  #   expect(message_1).to be(message_2) # same object is returned everytime you peek (until you pop)
  #   expect(size_before_peek).to eq(queue.size)
  #
  # @return [AstmMessage] the first element in the queue.
  def peek
    return nil if empty?
    @store.first
  end

  #
  # Returns the first element in the queue and removes it from the queue. See the
  # difference with {#peek} to determine which to use.
  #
  # @example
  #   size_before_peek = queue.size
  #   message_1 = queue.pop
  #   message_2 = queue.pop
  #   expect(message_1).to_not be(message_2) # should be 2 different objects (unless the same object was added twice)
  #   expect(size_before_peek).to eq(queue.size - 2) # 2 items less in the queue due to popping twice
  #
  # @return [AstmMessage] the first element in the queue.
  def pop
    @store.shift
  end

  #
  # Returns whether or not the queue is empty
  def empty?
    @store.empty?
  end

  #
  # Returns the size of the queue.
  def size
    @store.size
  end

  #
  # Clears the queue.
  def clear
    @store = []
  end
end