# Currency Conversion
Code Challenge - Neo Financial

## Problem
Neo is looking to find the best currency conversion possible for our customers.
However, we don’t have direct Canadian Dollar conversions to all currencies so
we have to trade currencies for other currencies. It is possible that we can go
from one currency to another, and that a currency could show up multiple times.

```
Example

Convert CAD to EUR
CAD -> GBP -> EUR

There are no cycles
CAD -> GBP -> EUR -> GBP
```

Utilizing the API data, return the best possible conversion rate for every
currency we can get, assuming we start with $100 CAD.

## API Endpoint
```
https://api-coding-challenge.neofinancial.com/currency-conversion?seed=12454
```

## Requirements
* Use one of the following languages: JavaScript, TypeScript, Java, C#, Python or Ruby
* Ensure you comment your code
* Use a REST call to get the data, do not hardcode it into your source code.
* Generate a CSV file as an output with the following format:
  * Currency Code (ie. CAD, USD, BTC)
  * Country (ie. Canada, USA, Bitcoin)
  * Amount of currency, given we started with $100 CDN (ie. 4000.43)
  * Path for the best conversion rate, pipe delimited (ie. CAD | GBP | EUR)

## Submit Your Solution
Zip the completed exercise and upload the file.
Please no node_modules or .git directories.
