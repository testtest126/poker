import { useState } from 'react'
import { Layout } from './components/Layout'
import { Home } from './pages/Home'
import { EquityCalculator } from './pages/EquityCalculator'
import { RangeExplorer } from './pages/RangeExplorer'

export type Page = 'home' | 'equity' | 'ranges'

function App() {
  const [page, setPage] = useState<Page>('home')

  return (
    <Layout page={page} onNavigate={setPage}>
      {page === 'home' && <Home onNavigate={setPage} />}
      {page === 'equity' && <EquityCalculator />}
      {page === 'ranges' && <RangeExplorer />}
    </Layout>
  )
}

export default App
