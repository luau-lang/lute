import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Lute",
  description: "Luau for General-Purpose Programming",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Guide', link: '/guide/installation' },
      { text: 'Reference', link: '/reference/fs' }
    ],

    sidebar: [
      {
        text: "Getting Started",
        items: [
          { text: 'Installation', link: '/guide/installation' },
        ]
      },
      {
        text: "Reference",
        items: [
          { text: 'fs', link: '/reference/fs' },
          { text: 'luau', link: '/reference/luau' },
          { text: 'net', link: '/reference/net' },
          { text: 'process', link: '/reference/process' },
          { text: 'system', link: '/reference/system' },
          { text: 'task', link: '/reference/task' },
          { text: 'vm', link: '/reference/vm' },
        ]
      }
    ],

    search: {
      provider: 'local'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/aatxe/lute' }
    ]
  }
})
