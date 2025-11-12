local types = require("../../types")

local retriever = {}

function retriever.rightmostToken<T>(t: types.Token<T>): types.Trivia?
	if #t.trailingtrivia > 0 then
		return t.trailingtrivia[#t.trailingtrivia]
	else
		return nil
	end
end

function retriever.rightmostPunctuated<T, S>(n: types.Punctuated<T, S>, rightmost: (T) -> types.Trivia?): types.Trivia?
	if #n > 0 then
		local last = n[#n]
		if last.separator ~= nil then
			return retriever.rightmostToken(last.separator)
		else
			return rightmost(last.node)
		end
	else
		return nil
	end
end

function retriever.rightmostExprGroup(n: types.AstExprGroup): types.Trivia?
	return retriever.rightmostToken(n.openparens)
end

function retriever.rightmostExprConstantNil(n: types.AstExprConstantNil): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostExprConstantBool(n: types.AstExprConstantBool): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostExprConstantNumber(n: types.AstExprConstantNumber): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostExprConstantString(n: types.AstExprConstantString): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostExprLocal(n: types.AstExprLocal): types.Trivia?
	return retriever.rightmostToken(n.token)
end

function retriever.rightmostExprGlobal(n: types.AstExprGlobal): types.Trivia?
	return retriever.rightmostToken(n.name)
end

function retriever.rightmostExprVarargs(n: types.AstExprVarargs): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostExprCall(n: types.AstExprCall): types.Trivia?
	if n.closeparens ~= nil then
		return retriever.rightmostToken(n.closeparens)
	elseif #n.arguments > 0 then
		return retriever.rightmostPunctuated(n.arguments, retriever.rightmostExpr)
	elseif n.openparens ~= nil then
		return retriever.rightmostToken(n.openparens)
	else
		return retriever.rightmostExpr(n.func)
	end
end

function retriever.rightmostExprIndexName(n: types.AstExprIndexName): types.Trivia?
	return retriever.rightmostToken(n.index)
end

function retriever.rightmostExprIndexExpr(n: types.AstExprIndexExpr): types.Trivia?
	return retriever.rightmostToken(n.closebrackets)
end

function retriever.rightmostExprAnonymousFunction(n: types.AstExprAnonymousFunction): types.Trivia?
	return retriever.rightmostToken(n.body.endkeyword)
end

function retriever.rightmostExprTable(n: types.AstExprTable): types.Trivia?
	return retriever.rightmostToken(n.closebrace)
end

function retriever.rightmostExprUnary(n: types.AstExprUnary): types.Trivia?
	return retriever.rightmostExpr(n.operand)
end

function retriever.rightmostExprBinary(n: types.AstExprBinary): types.Trivia?
	return retriever.rightmostExpr(n.rhsoperand)
end

function retriever.rightmostExprInterpString(n: types.AstExprInterpString): types.Trivia?
	if #n.strings > 0 then
		return retriever.rightmostToken(n.strings[#n.strings])
	else
		return nil
	end
end

function retriever.rightmostExprTypeAssertion(n: types.AstExprTypeAssertion): types.Trivia?
	return retriever.rightmostType(n.annotation)
end

function retriever.rightmostExprIfElse(n: types.AstExprIfElse): types.Trivia?
	return retriever.rightmostExpr(n.elseexpr)
end

function retriever.rightmostExpr(n: types.AstExpr): types.Trivia?
	if n.tag == "group" then
		return retriever.rightmostExprGroup(n)
	elseif n.tag == "nil" then
		return retriever.rightmostExprConstantNil(n)
	elseif n.tag == "boolean" then
		return retriever.rightmostExprConstantBool(n)
	elseif n.tag == "number" then
		return retriever.rightmostExprConstantNumber(n)
	elseif n.tag == "string" then
		return retriever.rightmostExprConstantString(n)
	elseif n.tag == "local" then
		return retriever.rightmostExprLocal(n)
	elseif n.tag == "global" then
		return retriever.rightmostExprGlobal(n)
	elseif n.tag == "vararg" then
		return retriever.rightmostExprVarargs(n)
	elseif n.tag == "call" then
		return retriever.rightmostExprCall(n)
	elseif n.tag == "indexname" then
		return retriever.rightmostExprIndexName(n)
	elseif n.tag == "index" then
		return retriever.rightmostExprIndexExpr(n)
	elseif n.tag == "function" then
		return retriever.rightmostExprAnonymousFunction(n)
	elseif n.tag == "table" then
		return retriever.rightmostExprTable(n)
	elseif n.tag == "unary" then
		return retriever.rightmostExprUnary(n)
	elseif n.tag == "binary" then
		return retriever.rightmostExprBinary(n)
	elseif n.tag == "interpolatedstring" then
		return retriever.rightmostExprInterpString(n)
	elseif n.tag == "cast" then
		return retriever.rightmostExprTypeAssertion(n)
	elseif n.tag == "conditional" then
		return retriever.rightmostExprIfElse(n)
	else
		error(`Unknown expr tag: {n.tag}`)
	end
end

function retriever.rightmostStatBlock(n: types.AstStatBlock): types.Trivia?
	if #n.statements > 0 then
		return retriever.rightmostStat(n.statements[#n.statements])
	else
		return nil
	end
end

function retriever.rightmostStatIf(n: types.AstStatIf): types.Trivia?
	return retriever.rightmostToken(n.endkeyword)
end

function retriever.rightmostStatWhile(n: types.AstStatWhile): types.Trivia?
	return retriever.rightmostToken(n.endkeyword)
end

function retriever.rightmostStatRepeat(n: types.AstStatRepeat): types.Trivia?
	return retriever.rightmostExpr(n.condition)
end

function retriever.rightmostStatBreak(n: types.AstStatBreak): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostStatContinue(n: types.AstStatContinue): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostStatReturn(n: types.AstStatReturn): types.Trivia?
	if #n.expressions > 0 then
		return retriever.rightmostPunctuated(n.expressions, retriever.rightmostExpr)
	else
		return retriever.rightmostToken(n.returnkeyword)
	end
end

function retriever.rightmostStatExpr(n: types.AstStatExpr): types.Trivia?
	return retriever.rightmostExpr(n.expression)
end

function retriever.rightmostStatLocal(n: types.AstStatLocal): types.Trivia?
	if #n.values > 0 then
		return retriever.rightmostPunctuated(n.values, retriever.rightmostExpr)
	elseif n.equals ~= nil then
		return retriever.rightmostToken(n.equals)
	elseif #n.variables > 0 then
		return retriever.rightmostPunctuated(n.variables, retriever.rightmostLocal)
	else
		return retriever.rightmostToken(n.localkeyword)
	end
end

function retriever.rightmostStatFor(n: types.AstStatFor): types.Trivia?
	return retriever.rightmostToken(n.endkeyword)
end

function retriever.rightmostStatForIn(n: types.AstStatForIn): types.Trivia?
	return retriever.rightmostToken(n.endkeyword)
end

function retriever.rightmostStatAssign(n: types.AstStatAssign): types.Trivia?
	if #n.values > 0 then
		return retriever.rightmostPunctuated(n.values, retriever.rightmostExpr)
	else
		return retriever.rightmostToken(n.equals)
	end
end

function retriever.rightmostStatCompoundAssign(n: types.AstStatCompoundAssign): types.Trivia?
	return retriever.rightmostExpr(n.value)
end

function retriever.rightmostStatFunction(n: types.AstStatFunction): types.Trivia?
	return retriever.rightmostToken(n.body.endkeyword)
end

function retriever.rightmostStatLocalFunction(n: types.AstStatLocalFunction): types.Trivia?
	return retriever.rightmostToken(n.body.endkeyword)
end

function retriever.rightmostStatTypeAlias(n: types.AstStatTypeAlias): types.Trivia?
	return retriever.rightmostType(n.type)
end

function retriever.rightmostStatTypeFunction(n: types.AstStatTypeFunction): types.Trivia?
	return retriever.rightmostToken(n.body.endkeyword)
end

function retriever.rightmostStat(n: types.AstStat): types.Trivia?
	if n.tag == "block" then
		return retriever.rightmostStatBlock(n)
	elseif n.tag == "if" then
		return retriever.rightmostStatIf(n)
	elseif n.tag == "while" then
		return retriever.rightmostStatWhile(n)
	elseif n.tag == "repeat" then
		return retriever.rightmostStatRepeat(n)
	elseif n.tag == "break" then
		return retriever.rightmostStatBreak(n)
	elseif n.tag == "continue" then
		return retriever.rightmostStatContinue(n)
	elseif n.tag == "return" then
		return retriever.rightmostStatReturn(n)
	elseif n.tag == "expression" then
		return retriever.rightmostStatExpr(n)
	elseif n.tag == "local" then
		return retriever.rightmostStatLocal(n)
	elseif n.tag == "for" then
		return retriever.rightmostStatFor(n)
	elseif n.tag == "forin" then
		return retriever.rightmostStatForIn(n)
	elseif n.tag == "assign" then
		return retriever.rightmostStatAssign(n)
	elseif n.tag == "compoundassign" then
		return retriever.rightmostStatCompoundAssign(n)
	elseif n.tag == "function" then
		return retriever.rightmostStatFunction(n)
	elseif n.tag == "localfunction" then
		return retriever.rightmostStatLocalFunction(n)
	elseif n.tag == "typealias" then
		return retriever.rightmostStatTypeAlias(n)
	elseif n.tag == "typefunction" then
		return retriever.rightmostStatTypeFunction(n)
	else
		error(`Unknown stat tag: {n.tag}`)
	end
end

function retriever.rightmostTypeReference(n: types.AstTypeReference): types.Trivia?
	if n.closeparameters ~= nil then
		return retriever.rightmostToken(n.closeparameters)
	elseif n.parameters ~= nil and #n.parameters > 0 then
		return retriever.rightmostPunctuated(n.parameters, function(n: types.AstType | types.AstTypePack): types.Trivia?
			if n.kind == "type" then
				return retriever.rightmostType(n)
			elseif n.kind == "typepack" then
				return retriever.rightmostTypePack(n)
			else
				error(`Invalid kind: {n.kind}`)
			end
		end)
	elseif n.openparameters ~= nil then
		return retriever.rightmostToken(n.openparameters)
	else
		return retriever.rightmostToken(n.name)
	end
end

function retriever.rightmostTypeSingletonBool(n: types.AstTypeSingletonBool): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostTypeSingletonString(n: types.AstTypeSingletonString): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostTypeTypeof(n: types.AstTypeTypeof): types.Trivia?
	return retriever.rightmostToken(n.closeparens)
end

function retriever.rightmostTypeGroup(n: types.AstTypeGroup): types.Trivia?
	return retriever.rightmostToken(n.closeparens)
end

function retriever.rightmostTypeUnion(n: types.AstTypeUnion): types.Trivia?
	if #n.types > 0 then
		return retriever.rightmostPunctuated(n.types, retriever.rightmostType)
	elseif n.leading ~= nil then
		return retriever.rightmostToken(n.leading)
	else
		return nil
	end
end

function retriever.rightmostTypeIntersection(n: types.AstTypeIntersection): types.Trivia?
	if #n.types > 0 then
		return retriever.rightmostPunctuated(n.types, retriever.rightmostType)
	elseif n.leading ~= nil then
		return retriever.rightmostToken(n.leading)
	else
		return nil
	end
end

function retriever.rightmostTypeOptional(n: types.AstTypeOptional): types.Trivia?
	return retriever.rightmostToken(n)
end

function retriever.rightmostTypeArray(n: types.AstTypeArray): types.Trivia?
	return retriever.rightmostToken(n.closebrace)
end

function retriever.rightmostTypeTable(n: types.AstTypeTable): types.Trivia?
	return retriever.rightmostToken(n.closebrace)
end

function retriever.rightmostGenericType(n: types.AstGenericType): types.Trivia?
	if n.default ~= nil then
		return retriever.rightmostType(n.default)
	elseif n.equals ~= nil then
		return retriever.rightmostToken(n.equals)
	else
		return retriever.rightmostToken(n.name)
	end
end

function retriever.rightmostGenericTypePack(n: types.AstGenericTypePack): types.Trivia?
	if n.default ~= nil then
		return retriever.rightmostTypePack(n.default)
	elseif n.equals ~= nil then
		return retriever.rightmostToken(n.equals)
	else
		return retriever.rightmostToken(n.ellipsis)
	end
end

function retriever.rightmostTypeFunction(n: types.AstTypeFunction): types.Trivia?
	return retriever.rightmostTypePack(n.returntypes)
end

function retriever.rightmostType(n: types.AstType): types.Trivia?
	if n.tag == "reference" then
		return retriever.rightmostTypeReference(n)
	elseif n.tag == "boolean" then
		return retriever.rightmostTypeSingletonBool(n)
	elseif n.tag == "string" then
		return retriever.rightmostTypeSingletonString(n)
	elseif n.tag == "typeof" then
		return retriever.rightmostTypeTypeof(n)
	elseif n.tag == "group" then
		return retriever.rightmostTypeGroup(n)
	elseif n.tag == "union" then
		return retriever.rightmostTypeUnion(n)
	elseif n.tag == "intersection" then
		return retriever.rightmostTypeIntersection(n)
	elseif n.tag == "optional" then
		return retriever.rightmostTypeOptional(n)
	elseif n.tag == "array" then
		return retriever.rightmostTypeArray(n)
	elseif n.tag == "table" then
		return retriever.rightmostTypeTable(n)
	elseif n.tag == "function" then
		return retriever.rightmostTypeFunction(n)
	else
		error(`Unknown type tag: {n.tag}`)
	end
end

function retriever.rightmostTypePackExplicit(n: types.AstTypePackExplicit): types.Trivia?
	if n.closeparens ~= nil then
		return retriever.rightmostToken(n.closeparens)
	elseif n.tailtype ~= nil then
		return retriever.rightmostTypePack(n.tailtype)
	elseif #n.types > 0 then
		return retriever.rightmostPunctuated(n.types, retriever.rightmostType)
	elseif n.openparens ~= nil then
		return retriever.rightmostToken(n.openparens)
	else
		return nil
	end
end

function retriever.rightmostTypePackGeneric(n: types.AstTypePackGeneric): types.Trivia?
	return retriever.rightmostToken(n.ellipsis)
end

function retriever.rightmostTypePackVariadic(n: types.AstTypePackVariadic): types.Trivia?
	return retriever.rightmostType(n.type)
end

function retriever.rightmostTypePack(n: types.AstTypePack): types.Trivia?
	if n.tag == "explicit" then
		return retriever.rightmostTypePackExplicit(n)
	elseif n.tag == "generic" then
		return retriever.rightmostTypePackGeneric(n)
	elseif n.tag == "variadic" then
		return retriever.rightmostTypePackVariadic(n)
	else
		error(`Unknown type pack tag: {n.tag}`)
	end
end

function retriever.rightmostLocal(n: types.AstLocal): types.Trivia?
	return retriever.rightmostToken(n.name)
end

function retriever.rightmostAttribute(n: types.AstAttribute): types.Trivia?
	return retriever.rightmostToken(n)
end

local retrieverLib = {}

function retrieverLib.rightmosttrivia(n: types.AstNode): types.Trivia?
	if n.kind == "expr" then
		return retriever.rightmostExpr(n, true) :: types.Trivia?
	elseif n.kind == "stat" then
		return retriever.rightmostStat(n, true) :: types.Trivia?
	elseif n.kind == "type" then
		return retriever.rightmostType(n, true) :: types.Trivia?
	elseif n.kind == "typepack" then
		return retriever.rightmostTypePack(n, true) :: types.Trivia?
	elseif n.kind == "local" then
		return retriever.rightmostLocal(n, true) :: types.Trivia?
	elseif n.kind == "attribute" then
		return retriever.rightmostAttribute(n, true) :: types.Trivia?
	else
		error(`Unknown node kind: {n.kind}`)
	end
end

return table.freeze(retrieverLib)
