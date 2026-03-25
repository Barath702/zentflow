import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Radio, ArrowUpDown, Clipboard, BarChart3, Settings as SettingsIcon } from 'lucide-react';
import DropZone from '@/components/DropZone';
import TransferList from '@/components/TransferList';
import ClipboardPanel from '@/components/ClipboardPanel';
import Analytics from '@/components/Analytics';
import SettingsPanel from '@/components/Settings';

const tabs = [
  { id: 'discover', icon: Radio, label: 'Discover' },
  { id: 'transfers', icon: ArrowUpDown, label: 'Transfers' },
  { id: 'clipboard', icon: Clipboard, label: 'Clipboard' },
  { id: 'stats', icon: BarChart3, label: 'Stats' },
  { id: 'settings', icon: SettingsIcon, label: 'Settings' },
];

const Index = () => {
  const [activeTab, setActiveTab] = useState('discover');

  return (
    <div className="min-h-screen bg-background relative overflow-hidden">
      {/* Background gradients */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute -top-32 -right-32 w-64 h-64 rounded-full opacity-20 gradient-primary blur-3xl" />
        <div className="absolute -bottom-32 -left-32 w-64 h-64 rounded-full opacity-15 gradient-accent blur-3xl" />
      </div>

      {/* Header */}
      <header className="relative z-10 px-4 pt-12 pb-4">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex items-center justify-between"
        >
          <div>
            <h1 className="font-display text-3xl font-bold gradient-text">Zent</h1>
            <p className="text-xs text-muted-foreground mt-0.5">Local file sharing</p>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full bg-success animate-pulse" />
            <span className="text-xs text-muted-foreground">On Network</span>
          </div>
        </motion.div>
      </header>

      {/* Content */}
      <main className="relative z-10">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeTab}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
          >
            {activeTab === 'discover' && <DropZone />}
            {activeTab === 'transfers' && <TransferList />}
            {activeTab === 'clipboard' && <ClipboardPanel />}
            {activeTab === 'stats' && <Analytics />}
            {activeTab === 'settings' && <SettingsPanel />}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Bottom Nav - improved with pill indicator */}
      <nav className="fixed bottom-0 left-0 right-0 z-50 px-3 pb-6 pt-2">
        <div className="glass-strong rounded-2xl px-2 py-2 flex items-center justify-around max-w-lg mx-auto">
          {tabs.map(tab => {
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className="relative flex flex-col items-center gap-0.5 px-3 py-1.5 rounded-xl transition-all duration-200"
              >
                {isActive && (
                  <motion.div
                    layoutId="activeTab"
                    className="absolute inset-0 rounded-xl"
                    style={{
                      background: 'linear-gradient(135deg, hsla(262, 83%, 58%, 0.15), hsla(199, 89%, 48%, 0.1))',
                      boxShadow: '0 0 12px hsla(262, 83%, 58%, 0.1)',
                    }}
                    transition={{ type: 'spring', stiffness: 500, damping: 35 }}
                  />
                )}
                <tab.icon className={`w-5 h-5 relative z-10 transition-colors duration-200 ${isActive ? 'text-primary' : 'text-muted-foreground'}`} />
                <span className={`text-[10px] font-medium relative z-10 transition-colors duration-200 ${isActive ? 'text-primary' : 'text-muted-foreground'}`}>
                  {tab.label}
                </span>
                {isActive && (
                  <motion.div
                    layoutId="activeIndicator"
                    className="absolute -bottom-0.5 w-4 h-0.5 rounded-full gradient-primary"
                    transition={{ type: 'spring', stiffness: 500, damping: 35 }}
                  />
                )}
              </button>
            );
          })}
        </div>
      </nav>
    </div>
  );
};

export default Index;
