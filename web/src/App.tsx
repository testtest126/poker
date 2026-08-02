import { useState } from 'react'
import { Layout } from './components/Layout'
import { Home } from './pages/Home'
import { EquityCalculator } from './pages/EquityCalculator'
import { RangeExplorer } from './pages/RangeExplorer'
import { ICMCalculator } from './pages/ICMCalculator'

export type Page = 'home' | 'equity' | 'ranges' | 'icm'

function App() {
  const [page, setPage] = useState<Page>('home')

  return (
    <Layout page={page} onNavigate={setPage}>
      {page === 'home' && <Home onNavigate={setPage} />}
      {page === 'equity' && <EquityCalculator />}
      {page === 'ranges' && <RangeExplorer />}
      {page === 'icm' && <ICMCalculator />}
    </Layout>
  )
}

export default App
