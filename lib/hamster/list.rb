require 'forwardable'
require 'monitor'

require 'hamster/set'

module Hamster

  class << self

    extend Forwardable

    def list(*items)
      items.reverse.reduce(EmptyList) { |list, item| list.cons(item) }
    end

    def stream(&block)
      return EmptyList unless block_given?
      Stream.new { Sequence.new(yield, stream(&block)) }
    end

    def interval(from, to)
      return EmptyList if from > to
      Stream.new { Sequence.new(from, interval(from.succ, to)) }
    end
    def_delegator :self, :interval, :range

    def repeat(item)
      Stream.new { Sequence.new(item, repeat(item)) }
    end

    def replicate(number, item)
      repeat(item).take(number)
    end

    def iterate(item, &block)
      Stream.new { Sequence.new(item, iterate(yield(item), &block)) }
    end

  end

  module List

    extend Forwardable

    Undefined = Object.new

    CADR = /^c([ad]+)r$/

    def first
      head
    end

    def empty?
      false
    end
    def_delegator :self, :empty?, :null?

    def size
      reduce(0) { |memo, item| memo.succ }
    end
    def_delegator :self, :size, :length

    def cons(item)
      Sequence.new(item, self)
    end
    def_delegator :self, :cons, :>>

    def each
      return self unless block_given?
      list = self
      while !list.empty?
        yield(list.head)
        list = list.tail
      end
    end
    def_delegator :self, :each, :foreach

    def map(&block)
      return self unless block_given?
      Stream.new do
        if empty?
          self
        else
          Sequence.new(yield(head), tail.map(&block))
        end
      end
    end
    def_delegator :self, :map, :collect

    def reduce(memo = Undefined, &block)
      return tail.reduce(head, &block) if memo.equal?(Undefined)
      return memo unless block_given?
      each { |item| memo = yield(memo, item)  }
      memo
    end
    def_delegator :self, :reduce, :inject
    def_delegator :self, :reduce, :fold

    def filter(&block)
      return self if empty?
      return self unless block_given?
      Stream.new do
        if yield(head)
          Sequence.new(head, tail.filter(&block))
        else
          tail.filter(&block)
        end
      end
    end
    def_delegator :self, :filter, :select
    def_delegator :self, :filter, :find_all

    def remove(&block)
      return self if empty?
      return self unless block_given?
      filter { |item| !yield(item) }
    end
    def_delegator :self, :remove, :reject
    def_delegator :self, :remove, :delete_if

    def take_while(&block)
      return self unless block_given?
      Stream.new do
        if empty?
          self
        elsif yield(head)
          Sequence.new(head, tail.take_while(&block))
        else
          EmptyList
        end
      end
    end

    def drop_while(&block)
      return self unless block_given?
      Stream.new do
        if empty?
          self
        elsif yield(head)
          tail.drop_while(&block)
        else
          self
        end
      end
    end

    def take(number)
      Stream.new do
        if empty?
          self
        elsif number > 0
          Sequence.new(head, tail.take(number - 1))
        else
          EmptyList
        end
      end
    end

    def drop(number)
      Stream.new do
        if empty?
          self
        elsif number > 0
          tail.drop(number - 1)
        else
          self
        end
      end
    end

    def include?(object)
      any? { |item| item == object }
    end
    def_delegator :self, :include?, :member?
    def_delegator :self, :include?, :contains?
    def_delegator :self, :include?, :elem?

    def any?(&block)
      return false if empty?
      return any? { |item| item } unless block_given?
      !! yield(head) || tail.any?(&block)
    end
    def_delegator :self, :any?, :exist?
    def_delegator :self, :any?, :exists?

    def all?(&block)
      return true if empty?
      return all? { |item| item } unless block_given?
      !! yield(head) && tail.all?(&block)
    end
    def_delegator :self, :all?, :forall?

    def none?(&block)
      return true if empty?
      return none? { |item| item } unless block_given?
      !yield(head) && tail.none?(&block)
    end

    def one?(&block)
      return false if empty?
      return one? { |item| item } unless block_given?
      return tail.none?(&block) if yield(head)
      tail.one?(&block)
    end

    def find(&block)
      return nil if empty?
      return nil unless block_given?
      return head if yield(head)
      tail.find(&block)
    end
    def_delegator :self, :find, :detect

    def partition(&block)
      return self unless block_given?
      Stream.new { Sequence.new(filter(&block), Sequence.new(remove(&block))) }
    end

    def append(other)
      return other if empty?
      Stream.new { Sequence.new(head, tail.append(other)) }
    end
    def_delegator :self, :append, :concat
    def_delegator :self, :append, :cat
    def_delegator :self, :append, :+

    def reverse
      reduce(EmptyList) { |list, item| list.cons(item) }
    end

    def minimum(&block)
      return minimum { |minimum, item| item <=> minimum } unless block_given?
      reduce { |minimum, item| yield(minimum, item) < 0 ? item : minimum }
    end
    def_delegator :self, :minimum, :min

    def maximum(&block)
      return maximum { |maximum, item| item <=> maximum } unless block_given?
      reduce { |maximum, item| yield(maximum, item) > 0 ? item : maximum }
    end
    def_delegator :self, :maximum, :max

    def grep(pattern, &block)
      filter { |item| pattern === item }.map(&block)
    end

    def zip(other)
      return self if empty? && other.empty?
      Stream.new { Sequence.new(Sequence.new(head, Sequence.new(other.head)), tail.zip(other.tail)) }
    end

    def cycle
      return self if empty?
      Stream.new { Sequence.new(head, tail.append(self.cycle)) }
    end

    def split_at(number)
      Sequence.new(take(number), Sequence.new(drop(number)))
    end

    def span(&block)
      return Sequence.new(self, Sequence.new(EmptyList)) unless block_given?
      Sequence.new(take_while(&block), Sequence.new(drop_while(&block)))
    end

    def break(&block)
      return Sequence.new(self, Sequence.new(EmptyList)) unless block_given?
      span { |item| !yield(item) }
    end

    def count(&block)
      filter(&block).size
    end

    def clear
      EmptyList
    end

    def sort(&block)
      Hamster.list(*to_a.sort(&block))
    end

    def sort_by(&block)
      return sort unless block_given?
      Hamster.list(*to_a.sort_by(&block))
    end

    def join(sep = "")
      return "" if empty?
      sep = sep.to_s
      tail.reduce(head.to_s) { |string, item| string << sep << item.to_s }
    end

    def intersperse(sep)
      return self if tail.empty?
      Stream.new { Sequence.new(head, Sequence.new(sep, tail.intersperse(sep))) }
    end

    def uniq(items = Set.new)
      return self if empty?
      return tail.uniq(items) if items.include?(head)
      Stream.new { Sequence.new(head, tail.uniq(items.add(head))) }
    end
    def_delegator :self, :uniq, :nub
    def_delegator :self, :uniq, :remove_duplicates

    def union(other)
      self.append(other).uniq
    end
    def_delegator :self, :union, :|

    def init
      return EmptyList if tail.empty?
      Stream.new { Sequence.new(head, tail.init) }
    end

    def last
      return head if tail.empty?
      tail.last
    end

    def product
      reduce(1, &:*)
    end

    def sum
      reduce(0, &:+)
    end

    def tails
      return Sequence.new(self) if empty?
      Stream.new { Sequence.new(self, tail.tails) }
    end

    def inits
      return Sequence.new(self) if empty?
      Stream.new { Sequence.new(EmptyList, tail.inits.map { |list| list.cons(head) }) }
    end

    def combinations(number)
      return Sequence.new(EmptyList) if number == 0
      return self if empty?
      Stream.new { tail.combinations(number - 1).map { |list| list.cons(head) }.append(tail.combinations(number)) }
    end
    def_delegator :self, :combinations, :combination

    def eql?(other)
      return false unless other.is_a?(List)

      list = self
      while !list.empty? && !other.empty?
        return true if other.equal?(list)
        return false unless other.is_a?(List)
        return false unless other.head.eql?(list.head)
        list = list.tail
        other = other.tail
      end

      other.empty? && list.empty?
    end
    def_delegator :self, :eql?, :==

    def dup
      self
    end
    def_delegator :self, :dup, :clone

    def to_a
      reduce([]) { |a, item| a << item }
    end
    def_delegator :self, :to_a, :to_ary
    def_delegator :self, :to_a, :entries

    def to_list
      self
    end

    def inspect
      to_a.inspect
    end

    def respond_to?(name, include_private = false)
      super || CADR === name
    end

    private

    def method_missing(name, *args, &block)
      if CADR === name
        accessor($1)
      else
        super
      end
    end

    # Perform compositions of <tt>car</tt> and <tt>cdr</tt> operations. Their names consist of a 'c', followed by at
    # least one 'a' or 'd', and finally an 'r'. The series of 'a's and 'd's in each function's name is chosen to
    # identify the series of car and cdr operations that is performed by the function. The order in which the 'a's and
    # 'd's appear is the inverse of the order in which the corresponding operations are performed.
    def accessor(sequence)
      sequence.split(//).reverse!.reduce(self) do |memo, char|
        case char
        when "a" then memo.head
        when "d" then memo.tail
        end
      end
    end

  end

  class Sequence

    include List

    attr_reader :head, :tail

    def initialize(head, tail = EmptyList)
      @head = head
      @tail = tail
    end

  end

  class Stream

    include List

    def initialize(&block)
      @block = block
      @mutex = Mutex.new
    end

    def head
      target.head
    end

    def tail
      target.tail
    end

    def empty?
      target.empty?
    end

    private

    def target
      @mutex.synchronize do
        unless defined?(@target)
          @target = @block.call
          @block = nil
        end
      end
      @target
    end

  end

  module EmptyList

    class << self

      include List

      def head
        nil
      end

      def tail
        self
      end

      def empty?
        true
      end

    end

  end

end
