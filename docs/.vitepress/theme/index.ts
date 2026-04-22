import DefaultTheme from 'vitepress/theme'
import { redirects } from './redirects'
import './style.css'

export default {
    ...DefaultTheme,
    enhanceApp({ router }: { router: any }) {
        router.onBeforeRouteChange = (to: string) => {
            const path = to.replace(/\.html$/i, ''),
                toPath = redirects[path]

            if (toPath) {
                setTimeout(() => { router.go(toPath) })
                return false
            } else {
                return true
            }
        }
    },
}
