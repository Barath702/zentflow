import { motion } from 'framer-motion';
import { FileText, HardDrive, Zap, TrendingUp } from 'lucide-react';
import { useZent } from '@/context/ZentContext';

const StatCard = ({ icon: Icon, label, value, gradient }: {
  icon: any; label: string; value: string; gradient: string;
}) => (
  <motion.div
    initial={{ opacity: 0, scale: 0.9 }}
    animate={{ opacity: 1, scale: 1 }}
    className="glass rounded-2xl p-4 flex flex-col gap-3"
  >
    <div className={`w-10 h-10 rounded-xl ${gradient} flex items-center justify-center`}>
      <Icon className="w-5 h-5 text-primary-foreground" />
    </div>
    <div>
      <p className="font-display text-2xl font-bold">{value}</p>
      <p className="text-xs text-muted-foreground">{label}</p>
    </div>
  </motion.div>
);

const Analytics = () => {
  const { totalTransferred, totalDataMB } = useZent();

  return (
    <div className="px-4 pb-24">
      <h2 className="font-display text-xl font-bold mb-4">Nerd Stats 🤓</h2>
      <div className="grid grid-cols-2 gap-3">
        <StatCard icon={FileText} label="Files Transferred" value={String(totalTransferred)} gradient="gradient-primary" />
        <StatCard icon={HardDrive} label="Data Shared" value={`${totalDataMB.toFixed(1)} MB`} gradient="gradient-accent" />
        <StatCard icon={TrendingUp} label="Data Saved" value={`${totalDataMB.toFixed(1)} MB`} gradient="gradient-warm" />
        <StatCard icon={Zap} label="Peak Speed" value="0 MB/s" gradient="gradient-primary" />
      </div>

      <div className="glass rounded-2xl p-4 mt-4">
        <p className="text-sm text-muted-foreground text-center">
          All transfers happen locally — no internet data used! 🌿
        </p>
      </div>
    </div>
  );
};

export default Analytics;
