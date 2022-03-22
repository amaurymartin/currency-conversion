# frozen_string_literal: true

require 'faraday'

class CurrencyAPI
  def initialize
    @conn = Faraday.new(url: 'https://api-coding-challenge.neofinancial.com')
  end

  def currency_conversion
    @conn.get('/currency-conversion', seed: '12454')
  end
end
