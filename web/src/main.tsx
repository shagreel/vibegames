import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { installCrashReporting } from './errors'
import { installAnalytics, trackPageView } from './analytics'
import { onPathChange } from './router'
import { installTitles } from './titles'

// Before anything renders: a throw while mounting is exactly the kind of
// failure nobody can report by hand.
installCrashReporting()

// Subscribed here rather than in a component on purpose. React runs effects
// twice in development, and a page view counted twice is worse than one not
// counted at all, because it looks like data.
onPathChange(trackPageView)

// The other thing that follows the route: what the tab says.
installTitles()

// Deliberately not awaited: the first frame should not wait on a counter, and
// `installAnalytics` reports the page that is already on screen once it is
// ready. Without a measurement id it does nothing at all.
void installAnalytics()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
