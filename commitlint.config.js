module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "type-enum": [
      2,
      "always",
      [
        "build",
        "chore",
        "ci",
        "docs",
        "feat",
        "fix",
        "refactor",
        "revert",
        "style",
        "test",
        "gas", // extended: gas optimization
      ],
    ],
  },
};
