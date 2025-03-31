export declare function rsml(content: string, derives?: StyleSheet[]): StyleSheet
export declare function rsml(content: TemplateStringsArray, ...rest: never | []): StyleSheet

export type TokenKind = 
    "CommentMultiStart" | 
    "StringMultiStart" | "StringMultiEnd" |
    "CommentSingle" | 
    "ScopeOpen" | "ScopeClose" | 
    "ParensOpen" | "ParensClose" | 
    "Comma" | "SemiColon" |
    "Equals" |
    "AttributeIdentifier" | "NameIdentifier" | "PsuedoIdentifier" | "StateOrEnumIdentifier" |
    "ScopeToDescendants" | "ScopeToChildren" |
    "PriorityDeclaration" | "DeriveDeclaration" | "NameDeclaration" | "DefaultsDeclaration" |
    "OpAdd" | "OpSub" | "OpMult" | "OpDiv" | "OpPow" | "OpMod" |
    "BoolTrue" | "BoolFalse" |
    "EnumKeyword" |
    "ColorTailwind" | "ColorBrick" | "ColorCss" | "ColorHex" | 
    "Number" | "Offset" | "ScaleOrOpMod" |
    "TagOrEnumIdentifier" |
    "StringSingle" |
    "RobloxAsset" |
    "Text" | "Error"

export type TokenDefinition = {
    Kind: TokenKind,
    Pattern: string
}

export type Token = {
    Kind: TokenKind,
    Value: string
}

export type Lexer = () => Token | undefined

export declare const lexRsml: (content: string) => Lexer

export type OperatorKind = "OpPow" | "OpDiv" | "OpMod" | "OpMult" | "OpAdd" | "OpSub"
export type OperatorSymbol = { Kind: "Operator", OperatorKind: OperatorKind }

export type TupleData = (Datatype | TupleData[])[]

export type DatatypeNone = { Kind: "None" }

export type IncompleteEnumShorthand = { Kind: "IncompleteEnumShorthand", Value: string }

export type Datatype = string | boolean | EnumItem | Color3 | number | UDim | UDim2 | OperatorSymbol | Vector3 | Rect | Font | Vector2 | DatatypeNone | TupleData | Content | Vector2int16 | Vector3int16 | IncompleteEnumShorthand | ColorSequence | NumberSequence

export type FinalizedDatatype = string | boolean | EnumItem | Color3 | number | UDim | UDim2 | Vector3 | Rect | Font | Vector2 | Content | Vector2int16 | Vector3int16 | ColorSequence | NumberSequence

export type TreeNode = {
    Attributes: { [Key: string]: FinalizedDatatype },
    Properties: { [Key: string]: FinalizedDatatype },
    Name?: string,
    Rules: TreeNode[],
    Derives: { [Key: string]: true },
    Selector?: string,
    Priority?: number,
    Parent: TreeNode
}

export declare const parseRsml: (lexer: Lexer) => TreeNode