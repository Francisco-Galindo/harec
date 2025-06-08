# Compiler

<div align="center">
  <img src="https://cloudfront-us-east-1.images.arcpublishing.com/infobae/QLXAPU64VVD7DMR5ZF7VIEH4HQ.jpg" alt="Logo UNAM" width="200"/>
  <p> Universidad Nacional Autónoma de México </p>
  <p> Ingeniería en Computación </p>
  <p> Compiladores </p>
  <p> Lexer - Lexical Analysis </p>
  <p> Alumnos: </p>
  <p>320198388</p>
  <p>320051665</p>
  <p>320298608</p>
  <p>320244612</p>
  <p>320054336</p>
  <p> Grupo 5 </p>
  <p> Semestre 2025-2 </p>
  <p> México, CDMX. Marzo 2025 </p>
</div>


## Introduction
In this project we will create a compiler, making also the parser that the compiler will use. Both the compiler and the parser will use hare programming language for implementing the program and as the language that will be compiled.

## Theorical Background
### About the parser
Parsing is a fundamental process in the field of computer science, especially within the domains of compilers, interpreters, and language processing systems. It involves analyzing a sequence of tokens or symbols based on the rules defined by a formal grammar, with the purpose of constructing a syntactic structure, often in the form of a parse tree or abstract syntax tree. Parsing techniques are generally classified into top-down and bottom-up methods. Recursive descent parsing belongs to the former category and is one of the most widely understood and implemented parsing strategies due to its straightforward and modular approach.

Recursive descent parsing operates by associating each non-terminal in a grammar with a corresponding function in the parser. These functions call one another in a recursive manner to recognize structures in the input, hence the term "recursive descent." As the input string is processed from left to right, the parser attempts to apply production rules that correspond to the structure of the grammar, descending through the hierarchy of rules until it either accepts the input or fails due to a mismatch.

This method is particularly suitable for grammars that conform to the LL(1) class, meaning they can be parsed from Left to right with Leftmost derivation using one lookahead token. However, for recursive descent to function correctly, the grammar must be free of left recursion. Left-recursive productions, which allow a non-terminal to appear as the leftmost symbol in one of its own derivations, can lead to infinite recursion and must therefore be transformed before the grammar can be parsed using this technique. Similarly, ambiguous or poorly factored grammars may require rewriting to ensure that decisions can be made deterministically based on the next token in the input stream.

Despite its advantages, recursive descent parsing does have limitations. Its reliance on grammars that are LL(1) restricts its applicability to a subset of possible languages. Moreover, maintaining a recursive descent parser for a large and complex grammar can become cumbersome and error-prone, particularly when compared to automated parser generators or more powerful bottom-up parsing techniques. Nevertheless, for many use cases, particularly those involving smaller grammars or where control and transparency are valued over generality, recursive descent remains an effective and reliable method.

### Compiler

## Development
### parser
For the parser there are multiple files used. With type.ha, using the lexer we obtain the datatypes and tokens of the elements so as to know what kind of expression are we working with.
with type.ha, we define the abstract type of data to represent expressions, verifying if the document is woring with normal expressions, with control structures, etc. After verifying all of this, it generates an abstract sintax tree depending on the type of structure found. The parser itself is in parse.ha which takes raw tokens produced by the lexer and transforms them into structured representations (AST nodes) that the compiler can analyze and eventually compile.

The primary function exposed from this file is called decls. It receives a pointer to a lexer and returns a list of parsed declarations. Internally, it uses a loop to keep parsing declarations until the lexer indicates that it has reached the end of the input. For each declaration it finds, it calls a helper function named decl_func, appends the resulting AST node to a list, and ensures that every declaration is followed by a semicolon. This function essentially builds up a complete list of top-level function declarations present in a source file.

The real core of the parser logic lies in the decl_func function. This function begins by confirming that the current token is the keyword fn, signaling the start of a function declaration. Then it expects an identifier, which will become the function’s name. After that, it parses the function’s prototype, which includes both the parameter list and the return type. This is stored using a standard AST type wrapper, and the location of the prototype in the source code is also recorded.

After parsing the prototype, the parser checks whether the function has a body or is merely declared without a body. This is done by looking for either an equal sign or a semicolon. If it finds an equal sign, the function has a body, and the parser expects a valid expression to follow, which it parses and stores as the function’s body. If it finds a semicolon, the parser assumes the function is only being declared and does not define a body at this point.

The resulting data is wrapped in an AST node representing a function declaration. This includes the function's name, prototype, body (if any), and some metadata like source code locations and attributes. The parser sets default values for things like whether the function is exported or whether it has any documentation, though those features could be added in the future.

### Compiler construction



### Test inputs



## Results



## Conclusion


## Sources

