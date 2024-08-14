@synopsis{
    Main function to generate a new TextMate grammar for Pico, to be used in the
    special VS Code extension
}

module VSCodePico

import Main;
extend lang::textmate::conversiontests::PicoWithCategories;

int main() = Main::main(rsc, "source.pico", |project://vscode-extension/syntaxes/pico.tmLanguage.json|);