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

The practical applications of recursive descent parsing are numerous and diverse. In compiler construction, especially for early or lightweight compilers, recursive descent is often employed to parse source code and produce intermediate representations. It is also a common choice in the design of domain-specific languages, where the simplicity and flexibility of this approach facilitate rapid development and easy maintenance. Additionally, recursive descent is frequently used in interpreters for custom scripting languages, in configuration file parsers, and in software tools such as static analyzers, linters, and code formatters, all of which benefit from the clarity and accessibility of a hand-written parsing approach.

Despite its advantages, recursive descent parsing does have limitations. Its reliance on grammars that are LL(1) restricts its applicability to a subset of possible languages. Moreover, maintaining a recursive descent parser for a large and complex grammar can become cumbersome and error-prone, particularly when compared to automated parser generators or more powerful bottom-up parsing techniques. Nevertheless, for many use cases, particularly those involving smaller grammars or where control and transparency are valued over generality, recursive descent remains an effective and reliable method.

### Compiler

## Development
### parser

### Compiler construction



### Test inputs



## Results



## Conclusion


## Sources

