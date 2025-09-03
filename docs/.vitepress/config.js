import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Statifier Documentation',
  description: 'SCXML State Machines for Elixir - Complete W3C compliant implementation',
  base: '/statifier/',
  
  head: [
    ['link', { rel: 'icon', href: '/statifier/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#6b46c1' }]
  ],

  themeConfig: {
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Get Started', link: '/getting-started' },
      { 
        text: 'Links', 
        items: [
          { text: 'GitHub', link: 'https://github.com/riddler/statifier' },
          { text: 'Hex Package', link: 'https://hex.pm/packages/statifier' },
          { text: 'Hex Docs', link: 'https://hexdocs.pm/statifier/' }
        ] 
      }
    ],

    sidebar: [
      {
        text: 'Introduction',
        items: [
          { text: 'What is Statifier?', link: '/' },
          { text: 'Getting Started', link: '/getting-started' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/riddler/statifier' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024 Riddler'
    },

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/riddler/statifier/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    }
  },

  markdown: {
    theme: 'github-dark',
    lineNumbers: true
  }
})