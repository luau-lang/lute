import { defineConfig } from 'vitepress'
import { withSidebar } from 'vitepress-sidebar'

export default withSidebar(
  defineConfig({
    title: 'Lute',
    description: 'Luau for General-Purpose Programming',
    base: "/",
    themeConfig: {
      nav: [
        { text: 'Guide', link: '/guide/installation' },
        { text: 'Reference', link: '/reference/definitions/crypto' },
      ],
      search: { provider: 'local' },
      socialLinks: [
        { icon: 'github', link: 'https://github.com/luau-lang/lute' },
      ],
    },
  }),
  {
    // ============ [ SIDEBAR OPTIONS ] ============
    useFolderLinkFromSameNameSubFile: true,
    useTitleFromFileHeading: true,
    useTitleFromFrontmatter: true,
    hyphenToSpace: true,
    underscoreToSpace: true,
    sortMenusByName: true,
    excludeByGlobPattern: ['**/test/**'],
  }
)
