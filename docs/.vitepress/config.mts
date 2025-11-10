import { defineConfig } from 'vitepress'
import { withSidebar } from 'vitepress-sidebar'

export default withSidebar(
  defineConfig({
    title: 'Lute',
    description: 'Luau for General-Purpose Programming',
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
    // ============ [ RESOLVING PATHS ] ============
    documentRootPath: './docs/',
    scanStartPath: './',
    // ============ [ GROUPING ] ============
    // collapsed: true,         // Collapse subgroups by default
    // ============ [ GETTING MENU TITLE ] ============
    useTitleFromFileHeading: true,
    useTitleFromFrontmatter: true,
    // ============ [ STYLING MENU TITLE ] ============
    hyphenToSpace: true,
    underscoreToSpace: true,
    // ============ [ SORTING ] ============
    sortMenusByName: true,
  }
)
