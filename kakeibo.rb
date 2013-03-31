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
      @accounts = {}
      config[:accounts].each do |filename|
        filename.sub! /(.yaml)?$/, '.yaml'
        account = Account.new filename
        @accounts[account.name] = account
      end
    end

    def save
      @accounts.each_value {|account| account.save }
    end

  end

end
