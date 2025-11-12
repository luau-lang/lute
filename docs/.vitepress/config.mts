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
        { text: 'Reference', link: '/reference/' },
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
    useFolderLinkFromIndexFile: false,
    hyphenToSpace: true,
    underscoreToSpace: true,
    sortMenusByName: true,
  }
)
