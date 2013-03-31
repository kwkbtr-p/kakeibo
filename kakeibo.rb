require 'date'
require 'set'
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
      @transactions = @data[:transactions] || {}
    end

    def set_total(date, total)
      @totals[Date.parse date] = total
    end

    def add_transaction(date, transaction)
      date = Date.parse date
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

    def initialize(config)
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
      @accounts.each_value {|account| account.save }
    end

    def get_date(date)
      begin
        Date.parse date
      rescue ArgumentError
        begin
          Date.parse @today.year + '-' + date
        rescue ArgumentError
          @today
        end
      end
    end
    private :get_date

    def find_account(name)
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

  end

end
