import { useEffect, useState } from 'react';
import { collection, getDocs, limit, query, startAfter, DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { db, functions } from '../../lib/firebaseClient';

interface MerchantItem {
  id: string;
  name?: string;
  email?: string;
  status?: string;
  blocked?: boolean;
  [key: string]: any;
}

const PAGE_SIZE = 20;

export default function MerchantsPage() {
  const [items, setItems] = useState<MerchantItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [cursor, setCursor] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState('');

  const fetchPage = async (startCursor?: QueryDocumentSnapshot<DocumentData>) => {
    setLoading(true);
    setError('');
    setSuccessMessage('');
    try {
      const baseQuery = startCursor
        ? query(collection(db, 'merchants'), startAfter(startCursor), limit(PAGE_SIZE))
        : query(collection(db, 'merchants'), limit(PAGE_SIZE));
      const snap = await getDocs(baseQuery);
      const docs = snap.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name || data.businessName,
          email: data.email,
          status: data.status,
          blocked: data.blocked,
          data
        } as MerchantItem;
      });
      setItems(docs);
      setCursor(snap.docs.length === PAGE_SIZE ? snap.docs[snap.docs.length - 1] : null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    } catch (err: any) {
      console.error('Failed to load merchants', err);
      setError(err?.message || 'Failed to load merchants');
      setItems([]);
      setCursor(null);
      setHasMore(false);
    } finally {
      setLoading(false);
    }
  };

  const handleSuspend = async (merchantId: string) => {
    if (!confirm('Are you sure you want to suspend this merchant?')) return;

    setActionLoading(merchantId);
    setError('');
    setSuccessMessage('');
    try {
      const updateMerchantStatus = httpsCallable(functions, 'adminUpdateMerchantStatus');
      await updateMerchantStatus({ merchantId, action: 'suspend' });
      setSuccessMessage(`Merchant ${merchantId} suspended successfully (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to suspend merchant', err);
      setError(err?.message || 'Failed to suspend merchant');
    } finally {
      setActionLoading(null);
    }
  };

  const handleActivate = async (merchantId: string) => {
    setActionLoading(merchantId);
    setError('');
    setSuccessMessage('');
    try {
      const updateMerchantStatus = httpsCallable(functions, 'adminUpdateMerchantStatus');
      await updateMerchantStatus({ merchantId, action: 'activate' });
      setSuccessMessage(`Merchant ${merchantId} activated successfully (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to activate merchant', err);
      setError(err?.message || 'Failed to activate merchant');
    } finally {
      setActionLoading(null);
    }
  };

  const handleBlock = async (merchantId: string) => {
    if (!confirm('Are you sure you want to PERMANENTLY BLOCK this merchant? This action is severe.')) return;

    setActionLoading(merchantId);
    setError('');
    setSuccessMessage('');
    try {
      const updateMerchantStatus = httpsCallable(functions, 'adminUpdateMerchantStatus');
      await updateMerchantStatus({ merchantId, action: 'block' });
      setSuccessMessage(`Merchant ${merchantId} blocked permanently (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to block merchant', err);
      setError(err?.message || 'Failed to block merchant');
    } finally {
      setActionLoading(null);
    }
  };

  useEffect(() => {
    fetchPage();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <AdminGuard>
      <AdminLayout title="Merchants Moderation">
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: '12px', gap: '8px' }}>
          <button
            onClick={() => fetchPage()}
            disabled={loading}
            style={{ padding: '8px 12px', border: '1px solid #e5e7eb', background: '#fff', cursor: 'pointer' }}
          >
            Refresh
          </button>
          <button
            onClick={() => cursor && fetchPage(cursor)}
            disabled={!hasMore || loading}
            style={{ padding: '8px 12px', border: '1px solid #e5e7eb', background: '#fff', cursor: hasMore && !loading ? 'pointer' : 'not-allowed' }}
          >
            Next 20
          </button>
          {loading && <span style={{ fontSize: '14px' }}>Loading...</span>}
          {error && <span style={{ color: '#b91c1c', fontSize: '14px' }}>{error}</span>}
          {successMessage && <span style={{ color: '#16a34a', fontSize: '14px' }}>{successMessage}</span>}
        </div>

        {items.length === 0 && !loading && !error && (
          <div style={{ padding: '12px', background: '#fff', border: '1px solid #e5e7eb' }}>No merchants found.</div>
        )}

        {items.length > 0 && (
          <div style={{ background: '#fff', border: '1px solid #e5e7eb' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb' }}>
                  <th style={{ padding: '8px' }}>ID</th>
                  <th style={{ padding: '8px' }}>Name</th>
                  <th style={{ padding: '8px' }}>Email</th>
                  <th style={{ padding: '8px' }}>Status</th>
                  <th style={{ padding: '8px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map(item => (
                  <tr key={item.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '8px', fontSize: '12px', color: '#4b5563' }}>{item.id}</td>
                    <td style={{ padding: '8px' }}>{item.name || '-'}</td>
                    <td style={{ padding: '8px' }}>{item.email || '-'}</td>
                    <td style={{ padding: '8px' }}>
                      <span style={{ 
                        padding: '2px 8px', 
                        borderRadius: '4px', 
                        fontSize: '12px',
                        background: item.blocked ? '#fee2e2' : item.status === 'active' ? '#d1fae5' : item.status === 'suspended' ? '#fef3c7' : '#f3f4f6',
                        color: item.blocked ? '#991b1b' : item.status === 'active' ? '#065f46' : item.status === 'suspended' ? '#92400e' : '#4b5563'
                      }}>
                        {item.blocked ? 'BLOCKED' : item.status || 'unknown'}
                      </span>
                    </td>
                    <td style={{ padding: '8px' }}>
                      <div style={{ display: 'flex', gap: '4px' }}>
                        {!item.blocked && item.status !== 'suspended' && (
                          <button
                            onClick={() => handleSuspend(item.id)}
                            disabled={actionLoading === item.id}
                            style={{ 
                              padding: '4px 8px', 
                              fontSize: '12px',
                              border: '1px solid #f59e0b', 
                              background: '#fff', 
                              color: '#f59e0b',
                              cursor: actionLoading === item.id ? 'not-allowed' : 'pointer'
                            }}
                          >
                            {actionLoading === item.id ? 'Loading...' : 'Suspend'}
                          </button>
                        )}
                        {!item.blocked && item.status === 'suspended' && (
                          <button
                            onClick={() => handleActivate(item.id)}
                            disabled={actionLoading === item.id}
                            style={{ 
                              padding: '4px 8px', 
                              fontSize: '12px',
                              border: '1px solid #10b981', 
                              background: '#fff', 
                              color: '#10b981',
                              cursor: actionLoading === item.id ? 'not-allowed' : 'pointer'
                            }}
                          >
                            {actionLoading === item.id ? 'Loading...' : 'Activate'}
                          </button>
                        )}
                        {!item.blocked && (
                          <button
                            onClick={() => handleBlock(item.id)}
                            disabled={actionLoading === item.id}
                            style={{ 
                              padding: '4px 8px', 
                              fontSize: '12px',
                              border: '1px solid #ef4444', 
                              background: '#fff', 
                              color: '#ef4444',
                              cursor: actionLoading === item.id ? 'not-allowed' : 'pointer'
                            }}
                          >
                            {actionLoading === item.id ? 'Loading...' : 'Block'}
                          </button>
                        )}
                        {item.blocked && (
                          <span style={{ fontSize: '12px', color: '#6b7280' }}>Permanently blocked</span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </AdminLayout>
    </AdminGuard>
  );
}
