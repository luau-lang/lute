import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Lute",
  description: "Luau for General-Purpose Programming",
  base: "/",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      { text: 'Guide', link: '/guide/installation' },
      { text: 'Reference', link: '/reference/definitions/crypto' }
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
          // Definitions
          { text: 'crypto', link: '/reference/definitions/crypto' },
          { text: 'fs', link: '/reference/definitions/fs' },
          { text: 'io', link: '/reference/definitions/io' },
          { text: 'luau', link: '/reference/definitions/luau' },
          { text: 'net', link: '/reference/definitions/net' },
          { text: 'process', link: '/reference/definitions/process' },
          { text: 'system', link: '/reference/definitions/system' },
          { text: 'task', link: '/reference/definitions/task' },
          { text: 'time', link: '/reference/definitions/time' },
          { text: 'vm', link: '/reference/definitions/vm' },

          // Standard Library subfolder
          {
            text: "Standard Library",
            items: [
              { text: 'assert', link: '/reference/std/assert' },
              { text: 'fs', link: '/reference/std/fs' },
              { text: 'io', link: '/reference/std/io' },
              { text: 'json', link: '/reference/std/json' },
              { text: 'luau', link: '/reference/std/luau' },
              { text: 'process', link: '/reference/std/process' },
              { text: 'stringext', link: '/reference/std/stringext' },
              { text: 'tableext', link: '/reference/std/tableext' },
              { text: 'task', link: '/reference/std/task' },
              { text: 'test', link: '/reference/std/test' },
              { text: 'vectorext', link: '/reference/std/vectorext' },

              // Path lib subfolder
              {
                text: "Path",
                items: [
                  { text: 'path', link: '/reference/std/path/path' },
                  { text: 'types', link: '/reference/std/path/types' },
                  // Posix lib subfolder
                  {
                    text: "Posix",
                    items: [
                      { text: 'posix', link: '/reference/std/path/posix/posix' },
                      { text: 'types', link: '/reference/std/path/posix/types' },
                    ]
                  },
                  // Win32 lib subfolder
                  {
                    text: "Win32",
                    items: [
                      { text: 'win32', link: '/reference/std/path/win32/win32' },
                      { text: 'types', link: '/reference/std/path/win32/types' },
                    ]
                  },
                ]
              },
              // Syntax lib subfolder
              {
                text: "Syntax",
                items: [
                  { text: 'parser', link: '/reference/std/syntax/parser' },
                  { text: 'printer', link: '/reference/std/syntax/printer' },
                  { text: 'query', link: '/reference/std/syntax/query' },
                  { text: 'visitor', link: '/reference/std/syntax/visitor' },
                ]
              },
              // System lib subfolder
              {
                text: "System",
                items: [
                  { text: 'system', link: '/reference/std/system/system' },
                  { text: 'platform', link: '/reference/std/system/platform' },
                ]
              },
              // Time lib subfolder
              {
                text: "Time",
                items: [
                  { text: 'time', link: '/reference/std/time/time' },
                  { text: 'duration', link: '/reference/std/time/duration' },
                ]
              }
            ]
          }
        ]
      }
    ],

    search: {
      provider: 'local'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/luau-lang/lute' }
    ]
  }
})
