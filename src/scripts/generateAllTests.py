def writeToFiles(path, content):
	f = open(path, "w")
	f.write(content)
	f.close()

ENUMERABLE_TYPE = ['Enumerable', 'MissingEnumerable']
CURVE_TYPE = ['ExponentialCurve', 'LinearCurve']
TOKEN_TYPE = ['ETH', 'Token']
FILE_OUT_PATH_BASE = 'test/new-tests/'

def generateAllTests():
	for enumerable in ENUMERABLE_TYPE:
		for curve in CURVE_TYPE:
			for token in TOKEN_TYPE:
				file_enumerable_type = "NoArb" + enumerable
				file_curve_type = "NoArb" + curve
				file_token_type = "NoArb" + token

				file_name = f"NoArb{curve}{enumerable}{token}"
				file_path = f"{FILE_OUT_PATH_BASE}{file_name}.t.sol"

				content = f"// SPDX-License-Identifier: MIT\n\npragma solidity ^0.8.0;\n\nimport {{{file_curve_type}}} from \"../abstract/{file_curve_type}.sol\";\nimport {{{file_enumerable_type}}} from \"../abstract/{file_enumerable_type}.sol\";\nimport {{{file_token_type}}} from \"../abstract/{file_token_type}.sol\";\n\ncontract {file_name}Test is {file_curve_type}, {file_enumerable_type}, {file_token_type} {{}}\n"

				writeToFiles(file_path, content)

generateAllTests()
print("Success")