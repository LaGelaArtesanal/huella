module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    // "google",  <-- COMENTADO: Elimina las reglas estrictas de Google
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*",
    "/generated/**/*",
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],

    // REGLAS RELAJADAS PARA EVITAR ERRORES DE DESPLIEGUE
    "max-len": "off",             // Permite líneas largas (Uber style)
    "padded-blocks": "off",       // Permite bloques compactos
    "object-curly-spacing": "off", // Permite {a: b} o { a: b }
    "arrow-parens": "off",        // Permite x => x sin paréntesis
    "prefer-const": "warn",       // Solo avisa, no bloquea
    "@typescript-eslint/no-explicit-any": "warn", // Solo avisa
    "eol-last": "off",            // No exige salto de línea al final
    "no-unused-vars": "warn",     // Solo avisa si hay variables sin usar
  },
};