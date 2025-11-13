local types = require("../../types")

local retriever = {}

function retriever.leftmostToken<T>(t: types.Token<T>): { types.Trivia }
	return t.leadingtrivia
end

function retriever.leftmostExprGroup(n: types.AstExprGroup): { types.Trivia }
	return retriever.leftmostToken(n.openparens)
end

function retriever.leftmostExprConstantNil(n: types.AstExprConstantNil): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostExprConstantBool(n: types.AstExprConstantBool): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostExprConstantNumber(n: types.AstExprConstantNumber): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostExprConstantString(n: types.AstExprConstantString): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostExprLocal(n: types.AstExprLocal): { types.Trivia }
	return retriever.leftmostToken(n.token)
end

function retriever.leftmostExprGlobal(n: types.AstExprGlobal): { types.Trivia }
	return retriever.leftmostToken(n.name)
end

function retriever.leftmostExprVarargs(n: types.AstExprVarargs): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostExprCall(n: types.AstExprCall): { types.Trivia }
	return retriever.leftmostExpr(n.func)
end

function retriever.leftmostExprIndexName(n: types.AstExprIndexName): { types.Trivia }
	return retriever.leftmostExpr(n.expression)
end

function retriever.leftmostExprIndexExpr(n: types.AstExprIndexExpr): { types.Trivia }
	return retriever.leftmostExpr(n.expression)
end

function retriever.leftmostExprAnonymousFunction(n: types.AstExprAnonymousFunction): { types.Trivia }
	if #n.attributes > 0 then
		return retriever.leftmostAttribute(n.attributes[1])
	else
		return retriever.leftmostToken(n.functionkeyword)
	end
end

function retriever.leftmostExprTable(n: types.AstExprTable): { types.Trivia }
	return retriever.leftmostToken(n.openbrace)
end

function retriever.leftmostExprUnary(n: types.AstExprUnary): { types.Trivia }
	return retriever.leftmostToken(n.operator)
end

function retriever.leftmostExprBinary(n: types.AstExprBinary): { types.Trivia }
	return retriever.leftmostExpr(n.lhsoperand)
end

function retriever.leftmostExprInterpString(n: types.AstExprInterpString): { types.Trivia }
	if #n.strings > 0 then
		return retriever.leftmostToken(n.strings[1])
	else
		return {}
	end
end

function retriever.leftmostExprTypeAssertion(n: types.AstExprTypeAssertion): { types.Trivia }
	return retriever.leftmostExpr(n.operand)
end

function retriever.leftmostExprIfElse(n: types.AstExprIfElse): { types.Trivia }
	return retriever.leftmostToken(n.ifkeyword)
end

function retriever.leftmostExpr(n: types.AstExpr): { types.Trivia }
	if n.tag == "group" then
		return retriever.leftmostExprGroup(n)
	elseif n.tag == "nil" then
		return retriever.leftmostExprConstantNil(n)
	elseif n.tag == "boolean" then
		return retriever.leftmostExprConstantBool(n)
	elseif n.tag == "number" then
		return retriever.leftmostExprConstantNumber(n)
	elseif n.tag == "string" then
		return retriever.leftmostExprConstantString(n)
	elseif n.tag == "local" then
		return retriever.leftmostExprLocal(n)
	elseif n.tag == "global" then
		return retriever.leftmostExprGlobal(n)
	elseif n.tag == "vararg" then
		return retriever.leftmostExprVarargs(n)
	elseif n.tag == "call" then
		return retriever.leftmostExprCall(n)
	elseif n.tag == "indexname" then
		return retriever.leftmostExprIndexName(n)
	elseif n.tag == "index" then
		return retriever.leftmostExprIndexExpr(n)
	elseif n.tag == "function" then
		return retriever.leftmostExprAnonymousFunction(n)
	elseif n.tag == "table" then
		return retriever.leftmostExprTable(n)
	elseif n.tag == "unary" then
		return retriever.leftmostExprUnary(n)
	elseif n.tag == "binary" then
		return retriever.leftmostExprBinary(n)
	elseif n.tag == "interpolatedstring" then
		return retriever.leftmostExprInterpString(n)
	elseif n.tag == "cast" then
		return retriever.leftmostExprTypeAssertion(n)
	elseif n.tag == "conditional" then
		return retriever.leftmostExprIfElse(n)
	else
		error(`Unknown expr tag: {n.tag}`)
	end
end

function retriever.leftmostStatBlock(n: types.AstStatBlock): { types.Trivia }
	if #n.statements > 0 then
		return retriever.leftmostStat(n.statements[1])
	else
		return {}
	end
end

function retriever.leftmostStatIf(n: types.AstStatIf): { types.Trivia }
	return retriever.leftmostToken(n.ifkeyword)
end

function retriever.leftmostStatWhile(n: types.AstStatWhile): { types.Trivia }
	return retriever.leftmostToken(n.whilekeyword)
end

function retriever.leftmostStatRepeat(n: types.AstStatRepeat): { types.Trivia }
	return retriever.leftmostToken(n.repeatKeyword)
end

function retriever.leftmostStatBreak(n: types.AstStatBreak): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostStatContinue(n: types.AstStatContinue): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostStatReturn(n: types.AstStatReturn): { types.Trivia }
	return retriever.leftmostToken(n.returnkeyword)
end

function retriever.leftmostStatExpr(n: types.AstStatExpr): { types.Trivia }
	return retriever.leftmostExpr(n.expression)
end

function retriever.leftmostStatLocal(n: types.AstStatLocal): { types.Trivia }
	return retriever.leftmostToken(n.localkeyword)
end

function retriever.leftmostStatFor(n: types.AstStatFor): { types.Trivia }
	return retriever.leftmostToken(n.forkeyword)
end

function retriever.leftmostStatForIn(n: types.AstStatForIn): { types.Trivia }
	return retriever.leftmostToken(n.forkeyword)
end

function retriever.leftmostStatAssign(n: types.AstStatAssign): { types.Trivia }
	if #n.variables > 0 then
		return retriever.leftmostExpr(n.variables[1].node)
	else
		return retriever.leftmostToken(n.equals)
	end
end

function retriever.leftmostStatCompoundAssign(n: types.AstStatCompoundAssign): { types.Trivia }
	return retriever.leftmostExpr(n.variable)
end

function retriever.leftmostStatFunction(n: types.AstStatFunction): { types.Trivia }
	if #n.attributes > 0 then
		return retriever.leftmostAttribute(n.attributes[1])
	else
		return retriever.leftmostToken(n.functionkeyword)
	end
end

function retriever.leftmostStatLocalFunction(n: types.AstStatLocalFunction): { types.Trivia }
	if #n.attributes > 0 then
		return retriever.leftmostAttribute(n.attributes[1])
	else
		return retriever.leftmostToken(n.localkeyword)
	end
end

function retriever.leftmostStatTypeAlias(n: types.AstStatTypeAlias): { types.Trivia }
	if n.export ~= nil then
		return retriever.leftmostToken(n.export)
	else
		return retriever.leftmostToken(n.typeToken)
	end
end

function retriever.leftmostStatTypeFunction(n: types.AstStatTypeFunction): { types.Trivia }
	if n.export ~= nil then
		return retriever.leftmostToken(n.export)
	else
		return retriever.leftmostToken(n.type)
	end
end

function retriever.leftmostStat(n: types.AstStat): { types.Trivia }
	if n.tag == "block" then
		return retriever.leftmostStatBlock(n)
	elseif n.tag == "if" then
		return retriever.leftmostStatIf(n)
	elseif n.tag == "while" then
		return retriever.leftmostStatWhile(n)
	elseif n.tag == "repeat" then
		return retriever.leftmostStatRepeat(n)
	elseif n.tag == "break" then
		return retriever.leftmostStatBreak(n)
	elseif n.tag == "continue" then
		return retriever.leftmostStatContinue(n)
	elseif n.tag == "return" then
		return retriever.leftmostStatReturn(n)
	elseif n.tag == "expression" then
		return retriever.leftmostStatExpr(n)
	elseif n.tag == "local" then
		return retriever.leftmostStatLocal(n)
	elseif n.tag == "for" then
		return retriever.leftmostStatFor(n)
	elseif n.tag == "forin" then
		return retriever.leftmostStatForIn(n)
	elseif n.tag == "assign" then
		return retriever.leftmostStatAssign(n)
	elseif n.tag == "compoundassign" then
		return retriever.leftmostStatCompoundAssign(n)
	elseif n.tag == "function" then
		return retriever.leftmostStatFunction(n)
	elseif n.tag == "localfunction" then
		return retriever.leftmostStatLocalFunction(n)
	elseif n.tag == "typealias" then
		return retriever.leftmostStatTypeAlias(n)
	elseif n.tag == "typefunction" then
		return retriever.leftmostStatTypeFunction(n)
	else
		error(`Unknown stat tag: {n.tag}`)
	end
end

function retriever.leftmostTypeReference(n: types.AstTypeReference): { types.Trivia }
	if n.prefix ~= nil then
		return retriever.leftmostToken(n.prefix)
	elseif n.prefixpoint ~= nil then
		return retriever.leftmostToken(n.prefixpoint)
	else
		return retriever.leftmostToken(n.name)
	end
end

function retriever.leftmostTypeSingletonBool(n: types.AstTypeSingletonBool): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostTypeSingletonString(n: types.AstTypeSingletonString): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostTypeTypeof(n: types.AstTypeTypeof): { types.Trivia }
	return retriever.leftmostToken(n.typeof)
end

function retriever.leftmostTypeGroup(n: types.AstTypeGroup): { types.Trivia }
	return retriever.leftmostToken(n.openparens)
end

function retriever.leftmostTypeUnion(n: types.AstTypeUnion): { types.Trivia }
	if n.leading ~= nil then
		return retriever.leftmostToken(n.leading)
	elseif #n.types > 0 then
		return retriever.leftmostType(n.types[1].node)
	else
		return {}
	end
end

function retriever.leftmostTypeIntersection(n: types.AstTypeIntersection): { types.Trivia }
	if n.leading ~= nil then
		return retriever.leftmostToken(n.leading)
	elseif #n.types > 0 then
		return retriever.leftmostType(n.types[1].node)
	else
		return {}
	end
end

function retriever.leftmostTypeOptional(n: types.AstTypeOptional): { types.Trivia }
	return retriever.leftmostToken(n)
end

function retriever.leftmostTypeArray(n: types.AstTypeArray): { types.Trivia }
	return retriever.leftmostToken(n.openbrace)
end

function retriever.leftmostTypeTable(n: types.AstTypeTable): { types.Trivia }
	return retriever.leftmostToken(n.openbrace)
end

function retriever.leftmostGenericType(n: types.AstGenericType): { types.Trivia }
	return retriever.leftmostToken(n.name)
end

function retriever.leftmostGenericTypePack(n: types.AstGenericTypePack): { types.Trivia }
	return retriever.leftmostToken(n.name)
end

function retriever.leftmostTypeFunction(n: types.AstTypeFunction): { types.Trivia }
	if n.opengenerics ~= nil then
		return retriever.leftmostToken(n.opengenerics)
	elseif n.generics ~= nil and #n.generics > 0 then
		return retriever.leftmostGenericType(n.generics[1].node)
	elseif n.genericpacks ~= nil and #n.genericpacks > 0 then
		return retriever.leftmostGenericTypePack(n.genericpacks[1].node)
	elseif n.closegenerics ~= nil then
		return retriever.leftmostToken(n.closegenerics)
	else
		return retriever.leftmostToken(n.openparens)
	end
end

function retriever.leftmostType(n: types.AstType): { types.Trivia }
	if n.tag == "reference" then
		return retriever.leftmostTypeReference(n)
	elseif n.tag == "boolean" then
		return retriever.leftmostTypeSingletonBool(n)
	elseif n.tag == "string" then
		return retriever.leftmostTypeSingletonString(n)
	elseif n.tag == "typeof" then
		return retriever.leftmostTypeTypeof(n)
	elseif n.tag == "group" then
		return retriever.leftmostTypeGroup(n)
	elseif n.tag == "union" then
		return retriever.leftmostTypeUnion(n)
	elseif n.tag == "intersection" then
		return retriever.leftmostTypeIntersection(n)
	elseif n.tag == "optional" then
		return retriever.leftmostTypeOptional(n)
	elseif n.tag == "array" then
		return retriever.leftmostTypeArray(n)
	elseif n.tag == "table" then
		return retriever.leftmostTypeTable(n)
	elseif n.tag == "function" then
		return retriever.leftmostTypeFunction(n)
	else
		error(`Unknown type tag: {n.tag}`)
	end
end

function retriever.leftmostTypePackExplicit(n: types.AstTypePackExplicit): { types.Trivia }
	if n.openparens ~= nil then
		return retriever.leftmostToken(n.openparens)
	elseif #n.types > 0 then
		return retriever.leftmostType(n.types[1].node)
	elseif n.tailtype ~= nil then
		return retriever.leftmostTypePack(n.tailtype)
	elseif n.closeparens ~= nil then
		return retriever.leftmostToken(n.closeparens)
	else
		return {}
	end
end

function retriever.leftmostTypePackGeneric(n: types.AstTypePackGeneric): { types.Trivia }
	return retriever.leftmostToken(n.name)
end

function retriever.leftmostTypePackVariadic(n: types.AstTypePackVariadic): { types.Trivia }
	if n.ellipsis ~= nil then
		return retriever.leftmostToken(n.ellipsis)
	else
		return retriever.leftmostType(n.type)
	end
end

function retriever.leftmostTypePack(n: types.AstTypePack): { types.Trivia }
	if n.tag == "explicit" then
		return retriever.leftmostTypePackExplicit(n)
	elseif n.tag == "generic" then
		return retriever.leftmostTypePackGeneric(n)
	elseif n.tag == "variadic" then
		return retriever.leftmostTypePackVariadic(n)
	else
		error(`Unknown type pack tag: {n.tag}`)
	end
end

function retriever.leftmostLocal(n: types.AstLocal): { types.Trivia }
	return retriever.leftmostToken(n.name)
end

function retriever.leftmostAttribute(n: types.AstAttribute): { types.Trivia }
	return retriever.leftmostToken(n)
end

local retrieverLib = {}

function retrieverLib.leftmosttrivia(n: types.AstNode): { types.Trivia }
	if n.kind == "expr" then
		return retriever.leftmostExpr(n, true) :: { types.Trivia }
	elseif n.kind == "stat" then
		return retriever.leftmostStat(n, true) :: { types.Trivia }
	elseif n.kind == "type" then
		return retriever.leftmostType(n, true) :: { types.Trivia }
	elseif n.kind == "typepack" then
		return retriever.leftmostTypePack(n, true) :: { types.Trivia }
	elseif n.kind == "local" then
		return retriever.leftmostLocal(n, true) :: { types.Trivia }
	elseif n.kind == "attribute" then
		return retriever.leftmostAttribute(n, true) :: { types.Trivia }
	else
		error(`Unknown node kind: {n.kind}`)
	end
end

return table.freeze(retrieverLib)
