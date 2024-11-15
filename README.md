# rascal-textmate

## Background

The aim of this project is to design and implement a scalable converter from
Rascal grammars to TextMate grammars. TextMate grammars generated in this way
are intended to be included in VS Code extensions to provide syntax highlighting
(complementary to Rascal's existing support for semantic highlighting).

In general, there are two possible approaches:
  - total conversion: produce equivalent TextMate rules for *all* Rascal
    non-terminals;
  - partial conversion: produce equivalent TextMate rules for *some* Rascal
    non-terminals "of interest" (e.g., those with a `@category` tag).

Due to the significant differences in expressiveness of Rascal grammars and
TextMate grammars, this project applies partial conversion. Alternatively, a
previous [project](https://github.com/TarVK/syntax-highlighter) by
[@TarVK](https://github.com/TarVK) applies total conversion.

## Usage

### Installing `rascal-textmate`

Enter the following commands in a terminal:

```shell
git clone https://github.com/SWAT-engineering/rascal-textmate.git
cd rascal-textmate/rascal-textmate-core
mvn install -Drascal.compile.skip -Drascal.tutor.skip -DskipTests
cd ../..
rm -rf rascal-textmate
```

### Running `rascal-textmate` in an existing Rascal project

 1. Add the following dependency in `pom.xml` of the project:

    ```xml
    <dependency>
      <groupId>org.rascalmpl</groupId>
      <artifactId>rascal-textmate-core</artifactId>
      <version>0.1.0-SNAPSHOT</version>
    </dependency>
    ```

 2. Add `|lib://rascal-textmate-core|` to `Require-Libraries` in
    `META-INF/RASCAL.MF` of the project.

 3. Open a REPL in a grammar module of the project, import module
    `lang::textmate::main::Main` in the REPL, and run function
    [`main`](https://github.com/SWAT-engineering/rascal-textmate/blob/69bd92c1e39b51c78ad6d49e680bba212a8df2a7/rascal-textmate-core/src/main/rascal/Main.rsc#L38-L47)
    on the `start` symbol of the grammar. For instance:

    ```rascal
    main(#Foo, "source.foo", |home:///Desktop/foo.json|)
    ```

    The generated TextMate grammar (as a JSON file) can now be integrated in a
    VS Code extension as explained
    [here](https://code.visualstudio.com/api/language-extensions/syntax-highlight-guide#contributing-a-basic-grammar).

## Contributing

### Documentation

The [walkthrough](rascal-textmate-core/src/main/rascal/lang/textmate/conversiontests/Walkthrough.rsc)
explains the main ideas behind the conversion algorithm.

### Tests

To test tokenization (as part of the conversion
[tests](rascal-textmate-core/src/main/rascal/lang/textmate/conversiontests)),
the [`vscode-tmgrammar-test`](https://github.com/PanAeon/vscode-tmgrammar-test)
tool is used. Install it locally in directory `rascal-textmate-core` as follows:

```
npm install vscode-tmgrammar-test
```