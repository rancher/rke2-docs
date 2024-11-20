# Website

This repo contains the contents of the RKE2 documentation website found at https://docs.rke2.io. Please open an issue if you have suggestions for new content or edits. We also gladly accept community PRs.

The website is built using [Docusaurus 2](https://docusaurus.io/), a modern static website generator.

### Installation

```
$ yarn
```

### Local Development

```
$ yarn start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Build

```
$ yarn build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

### Deployment

An automated GH action will deploy the website to [GitHub Pages](https://github.com/rancher/rke2-docs/tree/gh-pages) once a PR has been merged to `main`.
