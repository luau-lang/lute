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
        { text: 'CLI', link: '/cli/' },
        { text: 'Reference', link: '/reference' },
      ],
      search: { provider: 'local' },
      socialLinks: [
        { icon: 'github', link: 'https://github.com/luau-lang/lute' },
      ],
    },
  }),
  {
    // ============ [ SIDEBAR OPTIONS ] ============
    useFolderLinkFromIndexFile: true,
    useFolderTitleFromIndexFile: true,
    useTitleFromFileHeading: true,
    useTitleFromFrontmatter: true,
    hyphenToSpace: true,
    underscoreToSpace: true,
    sortMenusByFrontmatterOrder: true,
    frontmatterOrderDefaultValue: 100,
    excludeByGlobPattern: ['**/test/**', 'README.md'],
  }
)
