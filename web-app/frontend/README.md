# React + TypeScript + Vite SPA web app

Basic Single-Page Application connecting to the API.

## Stack

- [React](https://react.dev/) + [Vite](https://vite.dev/) + [TypeScript](https://www.typescriptlang.org/)
- [Mantine](https://mantine.dev/) UI with [PostCSS preset](https://mantine.dev/styles/postcss-preset) and CSS Modules
- [oxlint](https://oxc.rs/docs/guide/usage/linter) + [oxfmt](https://oxc.rs/) for linting and formatting; [Stylelint](https://stylelint.io/) for CSS
- [Vitest](https://vitest.dev/) + [Testing Library](https://testing-library.com/) for tests
- [Yarn 4](https://yarnpkg.com/) for package management
- REST client generated from the OpenAPI contract (`backend/api/openapi/counter.yaml`) via [openapi-typescript](https://openapi-ts.dev/) + [openapi-fetch](https://openapi-ts.dev/openapi-fetch/)

All tasks are exposed through the package `Taskfile.yml` (`task lint`, `task test`,
`task build`, `task dev`, …).
