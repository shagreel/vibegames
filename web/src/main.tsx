import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { installCrashReporting } from './errors'

// Before anything renders: a throw while mounting is exactly the kind of
// failure nobody can report by hand.
installCrashReporting()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
