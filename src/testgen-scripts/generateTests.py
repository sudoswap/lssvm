import csv

ENUMERABLE_TYPE = ['Enumerable', 'MissingEnumerable']
CURVE_TYPE = ['ExponentialCurve', 'LinearCurve', 'XykCurve']
TOKEN_TYPE = ['ETH', 'ERC20']
FILE_OUT_PATH_BASE = '../test/test-cases/'

def writeToFiles(path, content):
	f = open(path, "w")
	f.write(content)
	f.close()

def generateAllTests(base_test, prefix):
	for enumerable in ENUMERABLE_TYPE:
		for curve in CURVE_TYPE:
			for token in TOKEN_TYPE:
				file_enumerable_type = "Using" + enumerable
				file_curve_type = "Using" + curve
				file_token_type = "Using" + token

				file_name = prefix + f"{curve}{enumerable}{token}"
				file_path = f"{FILE_OUT_PATH_BASE}{file_name}.t.sol"

				content = f"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.8.0;\n\n"
				content += f"import {{{base_test}}} from \"../base/{base_test}.sol\";\n"
				content += f"import {{{file_curve_type}}} from \"../mixins/{file_curve_type}.sol\";\n"
				content += f"import {{{file_enumerable_type}}} from \"../mixins/{file_enumerable_type}.sol\";\n"
				content += f"import {{{file_token_type}}} from \"../mixins/{file_token_type}.sol\";\n\n"
				content += f"contract {file_name}Test is {base_test}, {file_curve_type}, {file_enumerable_type}, {file_token_type} {{}}\n"

				writeToFiles(file_path, content)

with open ('tests.csv') as f:
  tests = csv.reader(f)
  for t in tests:
    base_test_name = t[0]
    test_prefix = t[1]
    print(t)
    generateAllTests(base_test_name, test_prefix)
