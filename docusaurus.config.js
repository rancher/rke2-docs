
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
    locales: ["en"],
    localeConfigs: {
      en: {
        label: "English",
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
    announcementBar: {
      id: 'support_us',
      content:
        'Ingress-Nginx is going End-of-Life in <a href="https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/">March 2026</a>. Starting with v1.36, Traefik will be the default for new clusters. For existing clusters, see our <a href="/reference/ingress_migration">Migration Guide</a>.',
      backgroundColor: '#f3cf5a',
      textColor: '#091E42',
      isCloseable: true,
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
              className: 'navbar__icon navbar__suse',
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
  plugins: [
    [
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [
          { from: '/install/network_options', to: '/networking/basic_network_options' },
          { from: '/upgrades/automated_upgrade', to: '/upgrades/automated' },
          { from: '/upgrades/manual_upgrade', to: '/upgrades/manual' },
          { from: '/import-images', to: '/add-ons/import-images' },
          { from: '/helm', to: '/add-ons/helm' },
        ],
      },
    ],
  ],
  scripts: [
    {
      src: 'https://cdn.cookielaw.org/scripttemplates/otSDKStub.js',
      type:'text/javascript',
      charset: 'UTF-8',
      'data-domain-script': '019aa0c6-6fb3-75a4-a419-3ba567b7ccca',
      async: true
    },
    {
      src: '/scripts/optanonwrapper.js',
      type:'text/javascript',
      async: true
    },
  ],
};
