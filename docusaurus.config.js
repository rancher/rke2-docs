
/** @type {import('@docusaurus/types').DocusaurusConfig} */
module.exports = {
  title: 'RKE2',
  tagline: '',
  url: 'https://docs.rke2.io',
  baseUrl: '/',
  favicon: 'img/favicon.png',
  organizationName: 'rancher', // Usually your GitHub org/user name.
  projectName: 'rke2-docs', // Usually your repo name.
  trailingSlash: false,
  markdown: {
    mermaid: true,
  },
  i18n: {
    defaultLocale: "en",
    locales: ["en", "zh"],
    localeConfigs: {
      en: {
        label: "English",
      },
      zh: {
        label: "简体中文",
      },
    },
  },
  themeConfig: {
    colorMode: {
      // "light" | "dark"
      defaultMode: "light",

      // Hides the switch in the navbar
      // Useful if you want to support a single color mode
      disableSwitch: false,
    },
    navbar: {
      title: "",
      logo: {
        alt: 'logo',
        src: 'img/logo-horizontal-rke2.svg',
        srcDark: 'img/logo-horizontal-rke2-dark.svg',
      },
      items: [
        {
          type: 'search',
          position: 'right',
        },
        {
          type: "localeDropdown",
          position: "right",
        },
        {
          to: 'https://github.com/rancher/rke2',
          label: 'GitHub',
          position: 'right',
          className: 'navbar__icon navbar__github',
        },
        {
          type: 'dropdown',
          label: 'More From SUSE',
          position: 'right',
          items: [
            {
              label: 'Rancher',
              to: 'https://www.rancher.com',
              className: 'navbar__icon navbar__rancher',
            },
            {
              type: 'html',
              value: '<hr style="margin: 0.3rem 0;">',
            },
            {
              label: 'Harvester',
              to: "http://harvesterhci.io",
              className: 'navbar__icon navbar__harvester',
            },
            {
              label: 'Rancher Desktop',
              to: "https://rancherdesktop.io",
              className: 'navbar__icon navbar__rd',
            },
            {
              label: 'Kubewarden',
              to: "https://kubewarden.io",
              className: 'navbar__icon navbar__kubewarden',
            },
            {
              type: 'html',
              value: '<hr style="margin: 0.3rem 0;">',
            },
            {
              label: 'More Projects...',
              to: "https://opensource.suse.com",
            },
          ],
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
          editUrl: 'https://github.com/rancher/rke2-docs/edit/main/',
          exclude: ['migration.md'],
        },
        blog: false, // Optional: disable the blog plugin
        // ...
        theme: {
          customCss: [require.resolve("./src/css/custom.css")],
        },
        googleTagManager: {
          containerId: 'GTM-57KS2MW',
        },
      },
    ],
  ],
  themes: [
    '@docusaurus/theme-mermaid',
    [
      "@easyops-cn/docusaurus-search-local",
      /** @type {import("@easyops-cn/docusaurus-search-local").PluginOptions} */
      ({
        docsRouteBasePath: "/",
        hashed: true,
        highlightSearchTermsOnTargetPage: true,
        indexBlog: false,
      }),
    ],
  ],
};
