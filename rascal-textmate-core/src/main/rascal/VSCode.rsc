@synopsis{
    Main function to generate new TextMate grammars for Rascal and Pico, to be
    used in the special VS Code extension
}

module VSCode

import VSCodePico;
import VSCodeRascal;

int main() {
    VSCodePico::main();
    VSCodeRascal::main();
    return 0;
}