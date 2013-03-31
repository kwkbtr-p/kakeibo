require 'date'
require 'readline'
require 'yaml'

module Kakeibo

  module Util

    def self.loadfile(filename)
      raise 'invalid filename' unless filename && !filename.empty?
      open(filename) {|f| YAML.load(f)}
    end

    def self.savefile(data, filename)
      raise 'invalid filename' unless filename && !filename.empty?
      open(filename, 'w') {|f| YAML.dump(data, f)}
    end

  end

  class NotFoundException < Exception
    def initialize(name)
      super "Not found: #{name}"
    end
  end

  class NotUniqueException < Exception
    def initialize(name)
      super "Not unique: #{name}"
    end
  end

  class Account
    attr_accessor :filename
    attr_accessor :name

    def initialize(filename = nil)
      @filename = filename
      load if filename && !filename.empty?
    end

    def load
      @data = Util::loadfile @filename
      @name = @data[:name] || @filename.sub(/.yaml$/, '')
      @totals = @data[:totals] || {}
      @transactions = @data[:transactions] || []
    end

    def set_total(date, total)
      @totals[date] = total
    end

    def add_transaction(date, transaction)
      t = @transactions[date] || []
      t << transaction
      @transactions[date] = t
    end

    def save
      @data[:name] = @name
      @data[:totals] = @totals
      @data[:transactions] = @transactions
      Util::savefile @data, @filename
    end

  end

  class Transaction
    attr_accessor :amount
    attr_accessor :title
    attr_accessor :shop
    attr_accessor :category

    def initialize(amount = 0,
                   title = nil,
                   shop = nil,
                   category = nil)
      @amount = amount
      @title = title
      @shop = shop
      @category = category
    end

  end

  class Manager
    Account = Kakeibo::Account
    Transaction = Kakeibo::Transaction

    def initialize(config, reader)
      @reader = reader

      today = DateTime.now
      today = today.prev_day if today.hour < 6
      @today = Date.new today.year, today.month, today.day

      @accounts = []
      config[:accounts].each do |filename|
        filename.sub! /(.yaml)?$/, '.yaml'
        account = Account.new filename
        @accounts << account
      end
    end

    def save
      @accounts.each {|account| account.save }
    end

    def get_date(date)
      date = date || ""
      begin
        Date.parse date
      rescue ArgumentError
        begin
          Date.parse @today.year.to_s + '-' + date
        rescue ArgumentError
          @today
        end
      end
    end
    private :get_date

    def find_account(name)
      if name.empty?
        raise NotFoundException.new '(empty)'
      end

      r = /^#{name}/
      candidate = @accounts.find_all do |account|
        account.name =~ r
      end
      raise NotFoundException.new name if candidate.empty?
      raise NotUniqueException.new name if candidate.size > 1
      candidate[0]
    end
    private :find_account

    def put(data)
      date = get_date data[:date]
      account = find_account data[:account]
      if data[:total]
        account.set_total date, data[:total]
      else
        transaction = Transaction.new(data[:amount],
                                      data[:title],
                                      data[:shop],
                                      data[:category])
        account.add_transaction date, transaction
      end
    end

    def run
      @reader.read {|data| put data}
    end

  end

  class Reader

    def read
      r = /^=/

      while true

        begin
          data = {}

          amount = Readline.readline 'amount: '
          break unless amount && !amount.empty?
          data[:account] = Readline.readline 'account: ', true
          if amount =~ r
            data[:total] = amount.sub(r, '').to_i
          else
            data[:amount] = amount.to_i
            data[:title] = Readline.readline 'title: ', true
            data[:shop] = Readline.readline 'shop: ', true
            data[:category] = Readline.readline 'category: '
          end

          yield data

        rescue Interrupt
          puts
        end

      end
    end

  end

end

if __FILE__ == $0

  abort "usage: #{$0} config-file" if ARGV.size != 1

  require_relative ARGV[0]

  m = Kakeibo::Manager.new $config, Kakeibo::Reader.new

  m.run

  m.save

end
