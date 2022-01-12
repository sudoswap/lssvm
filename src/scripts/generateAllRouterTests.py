def writeToFiles(path, content):
	f = open(path, "w")
	f.write(content)
	f.close()

ENUMERABLE_TYPE = ['Enumerable', 'MissingEnumerable']
CURVE_TYPE = ['ExponentialCurve', 'LinearCurve']
TOKEN_TYPE = ['ETH', 'ERC20']
FILE_OUT_PATH_BASE = 'test/new-tests/'

base_test = "RouterBase"
test_name = "Router"

def generateAllTests():
	for enumerable in ENUMERABLE_TYPE:
		for curve in CURVE_TYPE:
			for token in TOKEN_TYPE:
				file_enumerable_type = "Using" + enumerable
				file_curve_type = "Using" + curve
				file_token_type = "Using" + token

				file_name = test_name + f"{curve}{enumerable}{token}"
				file_path = f"{FILE_OUT_PATH_BASE}{file_name}.t.sol"

				content = f"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.8.0;\n\n"
				content += f"import {{{base_test}{token}}} from \"../base/{base_test}{token}.sol\";\n"
				content += f"import {{{file_curve_type}}} from \"../mixins/{file_curve_type}.sol\";\n"
				content += f"import {{{file_enumerable_type}}} from \"../mixins/{file_enumerable_type}.sol\";\n"
				content += f"import {{{file_token_type}}} from \"../mixins/{file_token_type}.sol\";\n\n"
				content += f"contract {file_name}Test is {base_test}{token}, {file_curve_type}, {file_enumerable_type}, {file_token_type} {{}}\n"

				writeToFiles(file_path, content)

generateAllTests()
print("Router Tests Generated")