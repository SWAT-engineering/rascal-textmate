# rascal-textmate-core

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

The [walkthrough](src/main/rascal/lang/textmate/conversiontests/Walkthrough.rsc)
explains the main ideas behind the conversion algorithm in this project.
