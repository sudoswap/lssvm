import csv
import sys

ENUMERABLE_TYPE = ['Enumerable', 'MissingEnumerable']
CURVE_TYPE = ['ExponentialCurve', 'LinearCurve']
TOKEN_TYPE = ['ETH', 'ERC20']
FILE_OUT_PATH_BASE = '../test/test-cases/'
PNM_FILE_OUT_PATH_BASE = '../test/PNM/'
NEXT_LINE_WITH_INDENT = """
    """

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
				content += f"""contract {file_name}Test is
    {base_test},
    {file_curve_type},
    {file_enumerable_type},
    {file_token_type}
{{}}\n"""

				writeToFiles(file_path, content)

def generateAllPNMTests(base_test, prefix):
	base_test = "PNM" + base_test
	for enumerable in ENUMERABLE_TYPE:
		for curve in CURVE_TYPE:
			for token in TOKEN_TYPE:
				file_enumerable_type = "Using" + enumerable
				file_curve_type = "Using" + curve
				file_token_type = "Using" + token

				file_name = prefix + f"{curve}{enumerable}{token}"
				file_path = f"{PNM_FILE_OUT_PATH_BASE}{file_name}.t.sol"

				content = f"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.8.0;\n\n"
				content += f"import {{{base_test}}} from \"./base/{base_test}.sol\";\n"
				content += f"import {{{file_curve_type}}} from \"../mixins/{file_curve_type}.sol\";\n"
				content += f"import {{{file_enumerable_type}}} from \"../mixins/{file_enumerable_type}.sol\";\n"
				content += f"import {{{file_token_type}}} from \"../mixins/{file_token_type}.sol\";\n\n"
				content += f"""contract {file_name}Test is
    {base_test},
    {file_curve_type},
    {file_enumerable_type},
    {file_token_type}
{{}}\n"""

				writeToFiles(file_path, content)


if __name__ == "__main__":
	with open ('tests.csv') as f:
		tests = csv.reader(f)
		for t in tests:
			base_test_name = t[0]
			test_prefix = t[1]
			print(t)
			if len(sys.argv) > 1 and sys.argv[1] == "PNM":
				generateAllPNMTests(base_test_name, test_prefix)
			else:
				generateAllTests(base_test_name, test_prefix)