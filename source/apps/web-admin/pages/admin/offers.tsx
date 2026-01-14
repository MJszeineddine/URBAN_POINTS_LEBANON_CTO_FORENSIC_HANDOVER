import { useEffect, useState } from 'react';
import { collection, getDocs, limit, query, startAfter, DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { db, functions } from '../../lib/firebaseClient';

interface OfferItem {
  id: string;
  title?: string;
  points?: number;
  merchantId?: string;
  status?: string;
  [key: string]: any;
}

const PAGE_SIZE = 20;

export default function OffersPage() {
  const [items, setItems] = useState<OfferItem[]>([]);
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
        ? query(collection(db, 'offers'), startAfter(startCursor), limit(PAGE_SIZE))
        : query(collection(db, 'offers'), limit(PAGE_SIZE));
      const snap = await getDocs(baseQuery);
      const docs = snap.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          title: data.title,
          points: data.points || data.cost,
          merchantId: data.merchantId,
          status: data.status,
          data
        } as OfferItem;
      });
      setItems(docs);
      setCursor(snap.docs.length === PAGE_SIZE ? snap.docs[snap.docs.length - 1] : null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    } catch (err: any) {
      console.error('Failed to load offers', err);
      setError(err?.message || 'Failed to load offers');
      setItems([]);
      setCursor(null);
      setHasMore(false);
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (offerId: string) => {
    setActionLoading(offerId);
    setError('');
    setSuccessMessage('');
    try {
      const approveOffer = httpsCallable(functions, 'approveOffer');
      await approveOffer({ offerId });
      setSuccessMessage(`Offer ${offerId} approved successfully`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to approve offer', err);
      setError(err?.message || 'Failed to approve offer');
    } finally {
      setActionLoading(null);
    }
  };

  const handleReject = async (offerId: string) => {
    const reason = prompt('Enter rejection reason:');
    if (!reason) return;

    setActionLoading(offerId);
    setError('');
    setSuccessMessage('');
    try {
      const rejectOffer = httpsCallable(functions, 'rejectOffer');
      await rejectOffer({ offerId, reason });
      setSuccessMessage(`Offer ${offerId} rejected successfully`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to reject offer', err);
      setError(err?.message || 'Failed to reject offer');
    } finally {
      setActionLoading(null);
    }
  };

  const handleDisable = async (offerId: string) => {
    if (!confirm('Are you sure you want to disable this offer?')) return;

    setActionLoading(offerId);
    setError('');
    setSuccessMessage('');
    try {
      const disableOffer = httpsCallable(functions, 'adminDisableOffer');
      await disableOffer({ offerId, reason: 'disabled_via_admin_portal' });
      setSuccessMessage(`Offer ${offerId} disabled successfully (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to disable offer', err);
      setError(err?.message || 'Failed to disable offer');
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
      <AdminLayout title="Offers Moderation">
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
          <div style={{ padding: '12px', background: '#fff', border: '1px solid #e5e7eb' }}>No offers found.</div>
        )}

        {items.length > 0 && (
          <div style={{ background: '#fff', border: '1px solid #e5e7eb' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb' }}>
                  <th style={{ padding: '8px' }}>ID</th>
                  <th style={{ padding: '8px' }}>Title</th>
                  <th style={{ padding: '8px' }}>Points</th>
                  <th style={{ padding: '8px' }}>Merchant</th>
                  <th style={{ padding: '8px' }}>Status</th>
                  <th style={{ padding: '8px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map(item => (
                  <tr key={item.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '8px', fontSize: '12px', color: '#4b5563' }}>{item.id}</td>
                    <td style={{ padding: '8px' }}>{item.title || '-'}</td>
                    <td style={{ padding: '8px' }}>{item.points ?? '-'}</td>
                    <td style={{ padding: '8px' }}>{item.merchantId || '-'}</td>
                    <td style={{ padding: '8px' }}>
                      <span style={{ 
                        padding: '2px 8px', 
                        borderRadius: '4px', 
                        fontSize: '12px',
                        background: item.status === 'approved' ? '#d1fae5' : item.status === 'pending' ? '#fef3c7' : '#fee2e2',
                        color: item.status === 'approved' ? '#065f46' : item.status === 'pending' ? '#92400e' : '#991b1b'
                      }}>
                        {item.status || 'unknown'}
                      </span>
                    </td>
                    <td style={{ padding: '8px' }}>
                      <div style={{ display: 'flex', gap: '4px' }}>
                        {item.status === 'pending' && (
                          <>
                            <button
                              onClick={() => handleApprove(item.id)}
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
                              {actionLoading === item.id ? 'Loading...' : 'Approve'}
                            </button>
                            <button
                              onClick={() => handleReject(item.id)}
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
                              {actionLoading === item.id ? 'Loading...' : 'Reject'}
                            </button>
                          </>
                        )}
                        {(item.status === 'approved' || item.status === 'active') && (
                          <button
                            onClick={() => handleDisable(item.id)}
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
                            {actionLoading === item.id ? 'Loading...' : 'Disable'}
                          </button>
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
