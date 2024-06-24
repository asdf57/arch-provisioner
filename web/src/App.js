import React from 'react';
import './App.css';
import ProvisionComponent from './components/ProvisionComponent';
import { ProvisionContextProvider } from './contexts/ProvisionContext';
import Sidebar from './components/Sidebar';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import BuildISO from './components/BuildISO';

const App = () => {
  return (
    <BrowserRouter>
      <ProvisionContextProvider>
        <Sidebar />
        <Routes>
          <Route path="/buildiso" element={<BuildISO />} />
          <Route path="/provision" element={<ProvisionComponent />} />
        </Routes>

      </ProvisionContextProvider>
    </BrowserRouter>
  );
};

export default App;
