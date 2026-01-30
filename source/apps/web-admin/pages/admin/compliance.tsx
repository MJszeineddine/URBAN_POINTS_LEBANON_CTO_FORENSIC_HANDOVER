import { useEffect, useState } from 'react';
import { collection, getDocs, query, where } from 'firebase/firestore';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { db } from '../../lib/firebaseClient';

interface MerchantCompliance {
  id: string;
  name: string;
  email: string;
  activeOffers: number;
  subscriptionStatus: string;
  subscriptionEndDate?: string;
  complianceStatus: 'compliant' | 'warning' | 'non-compliant';
  issues: string[];
}

const MINIMUM_ACTIVE_OFFERS = 5;

export default function CompliancePage() {
  const [merchants, setMerchants] = useState<MerchantCompliance[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [filterStatus, setFilterStatus] = useState<'all' | 'compliant' | 'warning' | 'non-compliant'>('all');

  const fetchMerchantCompliance = async () => {
    setLoading(true);
    setError('');
    try {
      // Get all merchants
      const merchantsSnapshot = await getDocs(collection(db, 'merchants'));
      
      const complianceData: MerchantCompliance[] = [];

      for (const merchantDoc of merchantsSnapshot.docs) {
        const merchantData = merchantDoc.data() as any;
        
        // Get merchant's active offers
        const offersSnapshot = await getDocs(
          query(collection(db, 'offers'), 
            where('merchantId', '==', merchantDoc.id),
            where('status', '==', 'active')
          )
        );
        const activeOffers = offersSnapshot.size;

        // Get subscription info
        const subscriptionSnapshot = await getDocs(
          query(collection(db, 'subscriptions'),
            where('merchant_id', '==', merchantDoc.id),
            where('status', '==', 'active')
          )
        );
        const hasActiveSubscription = subscriptionSnapshot.size > 0;
        const subscription = subscriptionSnapshot.docs[0]?.data();

        // Determine compliance status
        const issues: string[] = [];
        let complianceStatus: 'compliant' | 'warning' | 'non-compliant' = 'compliant';

        if (activeOffers < MINIMUM_ACTIVE_OFFERS) {
          issues.push(`Only ${activeOffers}/${MINIMUM_ACTIVE_OFFERS} active offers`);
          complianceStatus = 'warning';
        }

        if (!hasActiveSubscription) {
          issues.push('No active subscription');
          complianceStatus = 'non-compliant';
        } else {
          const endDate = subscription?.end_date?.toDate?.();
          const today = new Date();
          if (endDate && endDate < today) {
            issues.push('Subscription expired');
            complianceStatus = 'non-compliant';
          } else if (endDate) {
            const daysUntilExpiry = Math.ceil((endDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
            if (daysUntilExpiry < 7) {
              issues.push(`Subscription expires in ${daysUntilExpiry} days`);
              if (complianceStatus === 'compliant') {
                complianceStatus = 'warning';
              }
            }
          }
        }

        complianceData.push({
          id: merchantDoc.id,
          name: merchantData.name || 'Unknown',
          email: merchantData.email || '',
          activeOffers,
          subscriptionStatus: hasActiveSubscription ? 'Active' : 'Inactive',
          subscriptionEndDate: subscription?.end_date?.toDate?.()?.toLocaleDateString(),
          complianceStatus,
          issues,
        });
      }

      setMerchants(complianceData.sort((a, b) => {
        // Sort by compliance status (non-compliant first)
        const statusOrder = { 'non-compliant': 0, 'warning': 1, 'compliant': 2 };
        return statusOrder[a.complianceStatus] - statusOrder[b.complianceStatus];
      }));
    } catch (err: any) {
      console.error('Failed to fetch merchant compliance', err);
      setError(err?.message || 'Failed to load compliance data');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMerchantCompliance();
  }, []);

  const filteredMerchants = merchants.filter(m => 
    filterStatus === 'all' ? true : m.complianceStatus === filterStatus
  );

  const stats = {
    total: merchants.length,
    compliant: merchants.filter(m => m.complianceStatus === 'compliant').length,
    warning: merchants.filter(m => m.complianceStatus === 'warning').length,
    nonCompliant: merchants.filter(m => m.complianceStatus === 'non-compliant').length,
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'compliant':
        return 'bg-green-100 text-green-800';
      case 'warning':
        return 'bg-yellow-100 text-yellow-800';
      case 'non-compliant':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <AdminGuard>
      <AdminLayout>
        <div className="p-6">
          <div className="mb-6">
            <h1 className="text-3xl font-bold text-gray-900">Merchant Compliance Monitor</h1>
            <p className="text-gray-600 mt-2">Track merchant compliance with platform requirements</p>
          </div>

          {error && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-800 rounded">
              {error}
            </div>
          )}

          {/* Compliance Summary */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-sm font-semibold text-gray-600 uppercase">Total Merchants</h3>
              <p className="text-3xl font-bold text-gray-900 mt-2">{stats.total}</p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow border-l-4 border-green-500">
              <h3 className="text-sm font-semibold text-gray-600 uppercase">Compliant</h3>
              <p className="text-3xl font-bold text-green-600 mt-2">{stats.compliant}</p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow border-l-4 border-yellow-500">
              <h3 className="text-sm font-semibold text-gray-600 uppercase">Warning</h3>
              <p className="text-3xl font-bold text-yellow-600 mt-2">{stats.warning}</p>
            </div>

            <div className="bg-white p-6 rounded-lg shadow border-l-4 border-red-500">
              <h3 className="text-sm font-semibold text-gray-600 uppercase">Non-Compliant</h3>
              <p className="text-3xl font-bold text-red-600 mt-2">{stats.nonCompliant}</p>
            </div>
          </div>

          {/* Controls */}
          <div className="mb-6 flex gap-4">
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value as any)}
              className="px-4 py-2 border border-gray-300 rounded focus:outline-none focus:border-blue-500"
            >
              <option value="all">All Merchants</option>
              <option value="compliant">Compliant Only</option>
              <option value="warning">Warning Only</option>
              <option value="non-compliant">Non-Compliant Only</option>
            </select>
            <button
              onClick={fetchMerchantCompliance}
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-400"
            >
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>

          {/* Merchants Table */}
          {loading ? (
            <div className="text-center py-12 text-gray-500">Loading merchant compliance data...</div>
          ) : filteredMerchants.length === 0 ? (
            <div className="text-center py-12 text-gray-500">No merchants found</div>
          ) : (
            <div className="bg-white rounded-lg shadow overflow-hidden">
              <table className="w-full">
                <thead className="bg-gray-100 border-b">
                  <tr>
                    <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Merchant</th>
                    <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Active Offers</th>
                    <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Subscription</th>
                    <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Status</th>
                    <th className="px-6 py-3 text-left text-sm font-semibold text-gray-700">Issues</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredMerchants.map((merchant) => (
                    <tr key={merchant.id} className="border-b hover:bg-gray-50">
                      <td className="px-6 py-4">
                        <div>
                          <p className="font-semibold text-gray-900">{merchant.name}</p>
                          <p className="text-sm text-gray-600">{merchant.email}</p>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <span className={`px-3 py-1 rounded-full text-sm font-semibold ${
                            merchant.activeOffers >= MINIMUM_ACTIVE_OFFERS
                              ? 'bg-green-100 text-green-800'
                              : 'bg-red-100 text-red-800'
                          }`}>
                            {merchant.activeOffers}/{MINIMUM_ACTIVE_OFFERS}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <div>
                          <p className="font-semibold text-gray-900">{merchant.subscriptionStatus}</p>
                          {merchant.subscriptionEndDate && (
                            <p className="text-sm text-gray-600">Expires: {merchant.subscriptionEndDate}</p>
                          )}
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`px-3 py-1 rounded-full text-sm font-semibold ${getStatusColor(merchant.complianceStatus)}`}>
                          {merchant.complianceStatus.charAt(0).toUpperCase() + merchant.complianceStatus.slice(1)}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        {merchant.issues.length > 0 ? (
                          <ul className="text-sm text-gray-700 space-y-1">
                            {merchant.issues.map((issue, idx) => (
                              <li key={idx} className="flex items-center gap-2">
                                <span className="text-red-600">•</span>
                                {issue}
                              </li>
                            ))}
                          </ul>
                        ) : (
                          <span className="text-green-600 text-sm">✓ All requirements met</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {/* Compliance Rules */}
          <div className="mt-8 bg-white p-6 rounded-lg shadow">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Compliance Requirements</h2>
            <ul className="space-y-3 text-gray-700">
              <li className="flex items-start gap-3">
                <span className="text-blue-600 font-bold mt-1">✓</span>
                <div>
                  <p className="font-semibold">Minimum Active Offers: {MINIMUM_ACTIVE_OFFERS}</p>
                  <p className="text-sm text-gray-600">Merchants must maintain at least {MINIMUM_ACTIVE_OFFERS} active offers</p>
                </div>
              </li>
              <li className="flex items-start gap-3">
                <span className="text-blue-600 font-bold mt-1">✓</span>
                <div>
                  <p className="font-semibold">Active Subscription Required</p>
                  <p className="text-sm text-gray-600">Merchants must have a current active subscription to be visible to customers</p>
                </div>
              </li>
              <li className="flex items-start gap-3">
                <span className="text-blue-600 font-bold mt-1">✓</span>
                <div>
                  <p className="font-semibold">Subscription Renewal Reminder (7 days before expiry)</p>
                  <p className="text-sm text-gray-600">Merchants receive notifications 7 days before subscription expires</p>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </AdminLayout>
    </AdminGuard>
  );
}
