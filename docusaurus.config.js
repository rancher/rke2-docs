
/** @type {import('@docusaurus/types').DocusaurusConfig} */
module.exports = {
  title: 'RKE 2',
  tagline: '',
  url: 'https://rancher.github.io/',
  baseUrl: '/rke2-docs/',
  favicon: 'img/favicon.ico',
  organizationName: 'rancher', // Usually your GitHub org/user name.
  projectName: 'rke2-docs', // Usually your repo name.
  trailingSlash: false,
  themeConfig: {
    colorMode: {
      // "light" | "dark"
      defaultMode: "light",

      // Hides the switch in the navbar
      // Useful if you want to support a single color mode
      disableSwitch: true,
    },
    navbar: {
      title: "",
      logo: {
        alt: 'logo',
        src: 'img/logo-horizontal-rke2.svg',
      },
      items: [
        {
          type: 'doc',
          docId: 'index',
          position: 'right',
          label: 'Docs',
          className: 'navbar__docs',
        },
        {
          href: 'https://github.com/rancher/rke2',
          label: 'GitHub',
          position: 'right',
          className: 'navbar__github btn btn-secondary icon-github',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [],
      copyright: `Copyright © ${new Date().getFullYear()} SUSE Rancher. All Rights Reserved.`,
    },
  },
  presets: [
    [
      '@docusaurus/preset-classic',
      {
        docs: {
          routeBasePath: '/', // Serve the docs at the site's root
          /* other docs plugin options */
          sidebarPath: require.resolve('./sidebars.js'),
          showLastUpdateTime: true,
          editUrl: 'https://github.com/kubewarden/docs/edit/main/',
        },
        blog: false, // Optional: disable the blog plugin
        // ...
        theme: {
          customCss: [require.resolve("./src/css/custom.css")],
        },
      },
    ],
  ], 
};
