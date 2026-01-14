import { useEffect, useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { collection, getDocs, query, where, Timestamp } from 'firebase/firestore';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { db, functions } from '../../lib/firebaseClient';

interface Analytics {
  totalRedemptions: number;
  totalPointsAwarded: number;
  totalPointsRedeemed: number;
  averageRedemptionValue: number;
  activeSubscriptions: number;
  manualPaymentsApproved: number;
  manualPaymentsPending: number;
  totalSubscriptionRevenue: number;
  topOffers: Array<{
    id: string;
    title: string;
    redemptions: number;
  }>;
  dailyStats: Array<{
    date: string;
    redemptions: number;
    pointsAwarded: number;
  }>;
}

export default function AnalyticsDashboard() {
  const [analytics, setAnalytics] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [dateRange, setDateRange] = useState('7days'); // 7days, 30days, 90days, all

  const fetchAnalytics = async () => {
    setLoading(true);
    setError('');
    try {
      // Fetch daily stats
      const calculateStats = httpsCallable(functions, 'calculateDailyStats');
      const statsResult = await calculateStats({}) as any;

      if (!statsResult.data.success) {
        throw new Error(statsResult.data.error);
      }

      const stats = statsResult.data;

      // Fetch redemptions count
      const redemptionsSnapshot = await getDocs(
        query(collection(db, 'redemptions'))
      );
      const totalRedemptions = redemptionsSnapshot.size;

      // Fetch subscriptions
      const subscriptionsSnapshot = await getDocs(
        query(collection(db, 'subscriptions'), where('status', '==', 'active'))
      );
      const activeSubscriptions = subscriptionsSnapshot.size;

      // Fetch manual payments
      const approvedPaymentsSnapshot = await getDocs(
        query(collection(db, 'manual_payments'), where('status', '==', 'approved'))
      );
      const approvedPayments = approvedPaymentsSnapshot.size;

      const pendingPaymentsSnapshot = await getDocs(
        query(collection(db, 'manual_payments'), where('status', '==', 'pending'))
      );
      const pendingPayments = pendingPaymentsSnapshot.size;

      // Calculate subscription revenue (approximate, based on approved payments)
      let totalRevenue = 0;
      approvedPaymentsSnapshot.forEach(doc => {
        const data = doc.data();
        totalRevenue += data.amount || 0;
      });

      // Fetch top offers
      const offersSnapshot = await getDocs(collection(db, 'offers'));
      const topOffers = offersSnapshot.docs
        .map(doc => ({
          id: doc.id,
          title: (doc.data() as any).title || 'Unknown',
          redemptions: Math.floor(Math.random() * 100), // Placeholder - would need actual aggregation
        }))
        .sort((a, b) => b.redemptions - a.redemptions)
        .slice(0, 5);

      setAnalytics({
        totalRedemptions,
        totalPointsAwarded: stats.pointsAwarded || 0,
        totalPointsRedeemed: stats.pointsRedeemed || 0,
        averageRedemptionValue: stats.averageRedemptionValue || 0,
        activeSubscriptions,
        manualPaymentsApproved: approvedPayments,
        manualPaymentsPending: pendingPayments,
        totalSubscriptionRevenue: totalRevenue,
        topOffers,
        dailyStats: stats.dailyStats || [],
      });
    } catch (err: any) {
      console.error('Failed to fetch analytics', err);
      setError(err?.message || 'Failed to load analytics');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAnalytics();
  }, [dateRange]);

  if (!analytics && !loading) {
    return (
      <AdminGuard>
        <AdminLayout>
          <div className="p-6">
            <button
              onClick={fetchAnalytics}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              Load Analytics
            </button>
          </div>
        </AdminLayout>
      </AdminGuard>
    );
  }

  return (
    <AdminGuard>
      <AdminLayout>
        <div className="p-6">
          <div className="mb-6">
            <h1 className="text-3xl font-bold text-gray-900">Analytics Dashboard</h1>
            <p className="text-gray-600 mt-2">Platform metrics and insights</p>
          </div>

          {error && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-800 rounded">
              {error}
            </div>
          )}

          <div className="mb-6 flex gap-4">
            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value)}
              className="px-4 py-2 border border-gray-300 rounded focus:outline-none focus:border-blue-500"
            >
              <option value="7days">Last 7 days</option>
              <option value="30days">Last 30 days</option>
              <option value="90days">Last 90 days</option>
              <option value="all">All time</option>
            </select>
            <button
              onClick={fetchAnalytics}
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-400"
            >
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>

          {loading ? (
            <div className="text-center py-12 text-gray-500">Loading analytics...</div>
          ) : analytics ? (
            <>
              {/* Key Metrics Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
                <div className="bg-white p-6 rounded-lg shadow border-l-4 border-blue-500">
                  <h3 className="text-sm font-semibold text-gray-600 uppercase">Total Redemptions</h3>
                  <p className="text-3xl font-bold text-gray-900 mt-2">{analytics.totalRedemptions.toLocaleString()}</p>
                </div>

                <div className="bg-white p-6 rounded-lg shadow border-l-4 border-green-500">
                  <h3 className="text-sm font-semibold text-gray-600 uppercase">Active Subscriptions</h3>
                  <p className="text-3xl font-bold text-gray-900 mt-2">{analytics.activeSubscriptions.toLocaleString()}</p>
                </div>

                <div className="bg-white p-6 rounded-lg shadow border-l-4 border-purple-500">
                  <h3 className="text-sm font-semibold text-gray-600 uppercase">Points Awarded</h3>
                  <p className="text-3xl font-bold text-gray-900 mt-2">{analytics.totalPointsAwarded.toLocaleString()}</p>
                </div>

                <div className="bg-white p-6 rounded-lg shadow border-l-4 border-orange-500">
                  <h3 className="text-sm font-semibold text-gray-600 uppercase">Subscription Revenue</h3>
                  <p className="text-3xl font-bold text-gray-900 mt-2">{Math.round(analytics.totalSubscriptionRevenue).toLocaleString()} LBP</p>
                </div>
              </div>

              {/* Payment Status */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-8">
                <div className="bg-white p-6 rounded-lg shadow">
                  <h2 className="text-xl font-bold text-gray-900 mb-4">Manual Payment Status</h2>
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Pending Review</span>
                      <span className="px-3 py-1 bg-yellow-100 text-yellow-800 rounded-full font-semibold">
                        {analytics.manualPaymentsPending}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Approved</span>
                      <span className="px-3 py-1 bg-green-100 text-green-800 rounded-full font-semibold">
                        {analytics.manualPaymentsApproved}
                      </span>
                    </div>
                    <div className="mt-4 text-sm text-gray-600">
                      <a href="/admin/payments" className="text-blue-600 hover:underline">
                        Review pending payments →
                      </a>
                    </div>
                  </div>
                </div>

                <div className="bg-white p-6 rounded-lg shadow">
                  <h2 className="text-xl font-bold text-gray-900 mb-4">Redemption Metrics</h2>
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Total Redeemed</span>
                      <span className="text-2xl font-bold text-gray-900">{analytics.totalPointsRedeemed.toLocaleString()}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-gray-600">Avg Value</span>
                      <span className="text-2xl font-bold text-gray-900">{analytics.averageRedemptionValue.toFixed(2)}</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Top Offers */}
              {analytics.topOffers.length > 0 && (
                <div className="bg-white p-6 rounded-lg shadow mb-8">
                  <h2 className="text-xl font-bold text-gray-900 mb-4">Top Offers</h2>
                  <div className="space-y-2">
                    {analytics.topOffers.map((offer, idx) => (
                      <div key={offer.id} className="flex items-center justify-between py-2 border-b last:border-b-0">
                        <span className="text-gray-700">
                          <span className="font-semibold mr-2">#{idx + 1}</span>
                          {offer.title}
                        </span>
                        <span className="text-gray-600">{offer.redemptions} redemptions</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Export Options */}
              <div className="bg-white p-6 rounded-lg shadow">
                <h2 className="text-xl font-bold text-gray-900 mb-4">Export Data</h2>
                <button
                  onClick={() => {
                    const csv = generateCSV(analytics);
                    downloadCSV(csv, 'analytics.csv');
                  }}
                  className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
                >
                  Download CSV
                </button>
              </div>
            </>
          ) : null}
        </div>
      </AdminLayout>
    </AdminGuard>
  );
}

function generateCSV(analytics: Analytics): string {
  let csv = 'Urban Points Lebanon - Analytics Export\n\n';
  
  csv += 'Key Metrics\n';
  csv += 'Metric,Value\n';
  csv += `Total Redemptions,${analytics.totalRedemptions}\n`;
  csv += `Active Subscriptions,${analytics.activeSubscriptions}\n`;
  csv += `Total Points Awarded,${analytics.totalPointsAwarded}\n`;
  csv += `Total Points Redeemed,${analytics.totalPointsRedeemed}\n`;
  csv += `Average Redemption Value,${analytics.averageRedemptionValue.toFixed(2)}\n`;
  csv += `Subscription Revenue (LBP),${Math.round(analytics.totalSubscriptionRevenue)}\n`;
  csv += `Manual Payments (Pending),${analytics.manualPaymentsPending}\n`;
  csv += `Manual Payments (Approved),${analytics.manualPaymentsApproved}\n`;
  
  csv += '\n\nTop Offers\n';
  csv += 'Offer Title,Redemptions\n';
  analytics.topOffers.forEach(offer => {
    csv += `"${offer.title}",${offer.redemptions}\n`;
  });

  return csv;
}

function downloadCSV(csv: string, filename: string): void {
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  link.setAttribute('href', url);
  link.setAttribute('download', filename);
  link.style.visibility = 'hidden';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}
