# frozen_string_literal: true

require 'csv'

require_relative 'currency_api'

class CurrencyConversion
  FILENAME = 'currency_conversion.csv'
  CSV_HEADERS = ['Currency Code', 'Country', 'Amount ($ 100 CAD)', 'Path'].freeze

  def generate_csv
    @conversions = from_api
    currencies = @conversions.map { |c| [c['toCurrencyCode'], c['toCurrencyName']] }.uniq.sort

    CSV.open(FILENAME, 'w', write_headers: true, headers: CSV_HEADERS) do |doc|
      # i = 1
      currencies.each do |currency|
        # next unless %w[TND UYU].include? currency.first

        conversion = convert_cad_to(currency.first) # ['BRL', 'Brazil Real'].first

        doc << [currency.first, country(currency.last), conversion[:amount], conversion[:path]]
        # i += 1
        # break if i > 21 # first n-elements
      end
    end
  end

  def from_api
    response = CurrencyAPI.new.currency_conversion

    return JSON.parse(response.body) if response.status == 200

    # throw error if we are unable to fetch API data
  end

  # cheaper than Switch/Case
  # however will fail for 'Turkish New Lira', resulting in 'Turkish New' instead of 'Turkey'
  def country(currency_name)
    currency_name_split = currency_name.split(' ')
    currency_name_split.size == 1 ? currency_name_split.join : currency_name_split.tap(&:pop).join(' ')
  end

  # return will be like:
  # { amount: 37.081858198, path: 'CAD | BTC | NANO | ADA' }
  # ready to be written on CSV file
  def convert_cad_to(currency_code)
    exchange_rate, path = best_conversion_to(currency_code)

    # at this point
    # exchange_rate variable is the multiplication of all rates involved
    # and path variable looks like: ['ADA', 'NANO', 'BTC', 'CAD']
    # thus, we need to invert the array and add '|'
    # TODO: we can truncate to float to two decimal places using round(2)
    { amount: (100 * exchange_rate), path: path.reverse.join(' | ') }
  end

  # return will be like:
  # 0.370818582, ['ADA', 'NANO', 'BTC', 'CAD']
  def best_conversion_to(currency_code)
    conversions = all_conversions_to(currency_code)
    # at this point
    # conversions variable is an array of all possible conversions and looks like
    # [
    #   { final_rate: 0.370818582, path: ['ADA', 'NANO', 'BTC', 'CAD'] }
    #   {  final_rate: 0.433176977, path: ['ADA', 'NANO', 'BTC', 'EUR', 'CAD'] }
    # ]

    # we only need conversion rates to calculate the best path
    final_rates = conversions.map { |c| c[:final_rate] }
    # since we already have final_rate, we can find the index of max value
    i = final_rates.index(final_rates.max)

    # knowing best conversion index, we can find the best path
    [conversions[i][:final_rate], conversions[i][:path]]
  end

  # return will be like:
  # [
  #   { final_rate: 0.370818582, path: ['ADA', 'NANO', 'BTC'] }
  #   {  final_rate: 0.433176977, path: ['ADA', 'NANO', 'BTC', 'EUR'] }
  # ]
  def all_conversions_to(currency_code, tree = [{ final_rate: 1, path: [] }])
    # since we are using recursion, this is our break point
    tree[-1][:path] << 'CAD' if currency_code == 'CAD'
    return tree if all_nodes_are_completed?(tree)

    # get all currencies that can be converted to our current currency
    conversions = currencies_that_can_be_converted_to(currency_code)

    # we may have a currency that cannot be converted to (eg BBD)
    # so for these cases, we return an "invalid" tree
    return [final_rate: 0, path: []] if conversions.empty?

    # at this point we can update the path with our current currency
    # but we can't udpate the rate since we can have more than one possible conversion
    # eg we can convert both CAD and GBP to EUR
    # so we know that EUR will be in our path
    # but at this point we don't know if we will use CAD -> EUR rate or GBP -> EUR rate
    tree[-1][:path] = tree[-1][:path] << conversions.first['toCurrencyCode']

    # we need to check if there's only one or more ways
    if conversions.one?
      # since we only have one possible conversion,
      # we can update our node with this conversion rate
      tree[-1][:final_rate] *= conversions.first['exchangeRate']

      # at this point we may have a tree like [AUD, EUR, GBP] and the next currency could be EUR
      # which will result in a tree with an endless cycle (eg [AUD, EUR, GBP, EUR, GBP, ..., EUR ])
      # therefore we need to compare the next currency with last but one element
      # this way we can prevent endless cycle by dropping it
      return tree.tap(&:pop) if conversions.first['fromCurrencyCode'] == tree[-1][:path][-2]

      # if we get here we can move on to the next conversion
      all_conversions_to(conversions.first['fromCurrencyCode'], tree)
    else
      # at this point we know that more than one conversion is possible
      # eg we can convert both CAD and GBP to EUR
      # so we need to go through all these possibilities
      conversions.each_with_index do |conversion, i|
        # since we are updating the tree recursively,
        # we need a snapshot of our last node at this specific moment.
        # We can't use dup or clone methods due to memory access
        # and ruby doesn't handle deep copy by default
        # If we were using rails, we could use deep_dup method, but since we are using pure ruby
        # we need to go with Marshal.load and Marshal.dump
        # reference:
        # https://medium.com/rubycademy/the-complete-guide-to-create-a-copy-of-an-object-in-ruby-part-ii-cd28a99d58d9
        last_node = Marshal.load(Marshal.dump(tree[-1]))

        # now we can update our final_rate knowing what conversion we will use
        tree[-1][:final_rate] *= conversion['exchangeRate']

        # recursion will allow us to get to the bottom of it and update our tree
        tree = all_conversions_to(conversion['fromCurrencyCode'], tree)

        # our tree is complete if we reached all the possibilities
        return tree if i == conversions.length - 1

        # at this point, if our tree is not complete,
        # we need to clone the last node, so we can continue to find other paths
        tree << last_node
      end
    end
  end

  def all_nodes_are_completed?(tree)
    # get all paths from tree
    paths = tree.map { |node| node[:path] }

    # tree is complete only if all paths end with CAD
    paths.reject { |path| path.last == 'CAD' }.empty?
  end

  def currencies_that_can_be_converted_to(currency_code)
    @conversions.select { |c| c['toCurrencyCode'] == currency_code }
  end
end
