`generateTests` is a Python script that takes all of the tests in `tests.csv` and creates all of the variants of `ETH/ERC20`, `Linear/Exponential`, and `Enumerable/MissingEnumerable` tests.

`tests.csv` has two columns. The first is the name of the test in `test/base`, and the second is the prefix that the generated tests will use. 

### Usage
`python generateTests.py`