# visitor

```luau
local visitor = require("@std/syntax/visitor")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [Visitor](#visitor) | A table of callbacks invoked during AST traversal. Each `visit` callback receives the corresponding node and |

---

## Types

### Visitor

A table of callbacks invoked during AST traversal. Each `visit` callback receives the corresponding node and

returns `true` to continue visiting its children, or `false` to skip them. "End" callbacks fire after all children

of that sort have been visited. Override only the callbacks you care about; unset callbacks default to visiting all children.

```luau
type Visitor = {
	visitStatBlock: (types.AstStatBlock) -> boolean,
	visitStatBlockEnd: (types.AstStatBlock) -> (),
	visitStatDo: (types.AstStatDo) -> boolean,
	visitStatIf: (types.AstStatIf) -> boolean,
	visitStatWhile: (types.AstStatWhile) -> boolean,
	visitStatRepeat: (types.AstStatRepeat) -> boolean,
	visitStatBreak: (types.AstStatBreak) -> boolean,
	visitStatContinue: (types.AstStatContinue) -> boolean,
	visitStatReturn: (types.AstStatReturn) -> boolean,
	visitStatLocalDeclaration: (types.AstStatLocal) -> boolean,
	visitStatLocalDeclarationEnd: (types.AstStatLocal) -> (),
	visitStatFor: (types.AstStatFor) -> boolean,
	visitStatForEnd: (types.AstStatFor) -> (),
	visitStatForIn: (types.AstStatForIn) -> boolean,
	visitStatForInEnd: (types.AstStatForIn) -> (),
	visitStatAssign: (types.AstStatAssign) -> boolean,
	visitStatCompoundAssign: (types.AstStatCompoundAssign) -> boolean,
	visitStatFunction: (types.AstStatFunction) -> boolean,
	visitStatLocalFunction: (types.AstStatLocalFunction) -> boolean,
	visitStatTypeAlias: (types.AstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (types.AstStatTypeFunction) -> boolean,
	visitStatExpr: (types.AstStatExpr) -> boolean,

	visitExpr: (types.AstExpr) -> boolean,
	visitExprEnd: (types.AstExpr) -> (),
	visitExprConstantNil: (types.AstExprConstantNil) -> boolean,
	visitExprConstantString: (types.AstExprConstantString) -> boolean,
	visitExprConstantBool: (types.AstExprConstantBool) -> boolean,
	visitExprConstantNumber: (types.AstExprConstantNumber) -> boolean,
	visitExprLocal: (types.AstExprLocal) -> boolean,
	visitExprGlobal: (types.AstExprGlobal) -> boolean,
	visitExprCall: (types.AstExprCall) -> boolean,
	visitExprUnary: (types.AstExprUnary) -> boolean,
	visitExprBinary: (types.AstExprBinary) -> boolean,
	visitExprFunction: (types.AstExprFunction) -> boolean,
	visitExprFunctionEnd: (types.AstExprFunction) -> (),
	visitExprInstantiate: (types.AstExprInstantiate) -> boolean,
	visitTableExprItem: (types.AstTableExprItem) -> boolean,
	visitExprTable: (types.AstExprTable) -> boolean,
	visitExprIndexName: (types.AstExprIndexName) -> boolean,
	visitExprIndexExpr: (types.AstExprIndexExpr) -> boolean,
	visitExprGroup: (types.AstExprGroup) -> boolean,
	visitExprInterpString: (types.AstExprInterpString) -> boolean,
	visitExprTypeAssertion: (types.AstExprTypeAssertion) -> boolean,
	visitExprIfElse: (types.AstExprIfElse) -> boolean,
	visitExprVarargs: (types.AstExprVarargs) -> boolean,

	visitTypeReference: (types.AstTypeReference) -> boolean,
	visitTypeSingletonBool: (types.AstTypeSingletonBool) -> boolean,
	visitTypeSingletonString: (types.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (types.AstTypeTypeof) -> boolean,
	visitTypeGroup: (types.AstTypeGroup) -> boolean,
	visitTypeOptional: (types.AstTypeOptional) -> boolean,
	visitTypeUnion: (types.AstTypeUnion) -> boolean,
	visitTypeIntersection: (types.AstTypeIntersection) -> boolean,
	visitTypeArray: (types.AstTypeArray) -> boolean,
	visitTypeTable: (types.AstTypeTable) -> boolean,
	visitTypeFunction: (types.AstTypeFunction) -> boolean,

	visitTypePackExplicit: (types.AstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (types.AstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (types.AstTypePackVariadic) -> boolean,

	visitToken: (types.Token) -> boolean,

	visitLocal: (types.AstLocal) -> boolean,

	visitAttribute: (types.AstAttribute) -> boolean,
}
```

---
