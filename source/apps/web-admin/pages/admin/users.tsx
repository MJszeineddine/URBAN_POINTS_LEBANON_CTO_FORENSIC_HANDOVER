import { useEffect, useState } from 'react';
import { collection, getDocs, limit, query, startAfter, DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { db, functions } from '../../lib/firebaseClient';

interface UserItem {
  id: string;
  email?: string;
  displayName?: string;
  role?: string;
  banned?: boolean;
  [key: string]: any;
}

const PAGE_SIZE = 20;

export default function UsersPage() {
  const [items, setItems] = useState<UserItem[]>([]);
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
        ? query(collection(db, 'users'), startAfter(startCursor), limit(PAGE_SIZE))
        : query(collection(db, 'users'), limit(PAGE_SIZE));
      const snap = await getDocs(baseQuery);
      const docs = snap.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          email: data.email,
          displayName: data.displayName || data.name,
          role: data.role || data.customClaims?.role,
          banned: data.banned,
          data
        } as UserItem;
      });
      setItems(docs);
      setCursor(snap.docs.length === PAGE_SIZE ? snap.docs[snap.docs.length - 1] : null);
      setHasMore(snap.docs.length === PAGE_SIZE);
    } catch (err: any) {
      console.error('Failed to load users', err);
      setError(err?.message || 'Failed to load users');
      setItems([]);
      setCursor(null);
      setHasMore(false);
    } finally {
      setLoading(false);
    }
  };

  const handleBan = async (userId: string) => {
    if (!confirm('Are you sure you want to ban this user?')) return;

    setActionLoading(userId);
    setError('');
    setSuccessMessage('');
    try {
      const banUser = httpsCallable(functions, 'adminBanUser');
      await banUser({ userId });
      setSuccessMessage(`User ${userId} banned successfully (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to ban user', err);
      setError(err?.message || 'Failed to ban user');
    } finally {
      setActionLoading(null);
    }
  };

  const handleUnban = async (userId: string) => {
    setActionLoading(userId);
    setError('');
    setSuccessMessage('');
    try {
      const unbanUser = httpsCallable(functions, 'adminUnbanUser');
      await unbanUser({ userId });
      setSuccessMessage(`User ${userId} unbanned successfully (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to unban user', err);
      setError(err?.message || 'Failed to unban user');
    } finally {
      setActionLoading(null);
    }
  };

  const handleChangeRole = async (userId: string, currentRole?: string) => {
    const newRole = prompt('Enter new role (customer, merchant, admin):', currentRole || 'customer');
    if (!newRole || !['customer', 'merchant', 'admin'].includes(newRole)) {
      alert('Invalid role. Must be: customer, merchant, or admin');
      return;
    }

    setActionLoading(userId);
    setError('');
    setSuccessMessage('');
    try {
      const updateUserRole = httpsCallable(functions, 'adminUpdateUserRole');
      await updateUserRole({ userId, role: newRole });
      setSuccessMessage(`User ${userId} role changed to ${newRole} (admin callable)`);
      await fetchPage();
    } catch (err: any) {
      console.error('Failed to change user role', err);
      setError(err?.message || 'Failed to change user role');
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
      <AdminLayout title="Users Moderation">
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
          <div style={{ padding: '12px', background: '#fff', border: '1px solid #e5e7eb' }}>No users found.</div>
        )}

        {items.length > 0 && (
          <div style={{ background: '#fff', border: '1px solid #e5e7eb' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb' }}>
                  <th style={{ padding: '8px' }}>ID</th>
                  <th style={{ padding: '8px' }}>Email</th>
                  <th style={{ padding: '8px' }}>Name</th>
                  <th style={{ padding: '8px' }}>Role</th>
                  <th style={{ padding: '8px' }}>Status</th>
                  <th style={{ padding: '8px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.map(item => (
                  <tr key={item.id} style={{ borderBottom: '1px solid #f3f4f6' }}>
                    <td style={{ padding: '8px', fontSize: '12px', color: '#4b5563' }}>{item.id}</td>
                    <td style={{ padding: '8px' }}>{item.email || '-'}</td>
                    <td style={{ padding: '8px' }}>{item.displayName || '-'}</td>
                    <td style={{ padding: '8px' }}>
                      <span style={{ 
                        padding: '2px 8px', 
                        borderRadius: '4px', 
                        fontSize: '12px',
                        background: item.role === 'admin' ? '#dbeafe' : item.role === 'merchant' ? '#e0e7ff' : '#f3f4f6',
                        color: item.role === 'admin' ? '#1e40af' : item.role === 'merchant' ? '#4338ca' : '#4b5563'
                      }}>
                        {item.role || 'customer'}
                      </span>
                    </td>
                    <td style={{ padding: '8px' }}>
                      <span style={{ 
                        padding: '2px 8px', 
                        borderRadius: '4px', 
                        fontSize: '12px',
                        background: item.banned ? '#fee2e2' : '#d1fae5',
                        color: item.banned ? '#991b1b' : '#065f46'
                      }}>
                        {item.banned ? 'BANNED' : 'Active'}
                      </span>
                    </td>
                    <td style={{ padding: '8px' }}>
                      <div style={{ display: 'flex', gap: '4px' }}>
                        {!item.banned && (
                          <button
                            onClick={() => handleBan(item.id)}
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
                            {actionLoading === item.id ? 'Loading...' : 'Ban'}
                          </button>
                        )}
                        {item.banned && (
                          <button
                            onClick={() => handleUnban(item.id)}
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
                            {actionLoading === item.id ? 'Loading...' : 'Unban'}
                          </button>
                        )}
                        <button
                          onClick={() => handleChangeRole(item.id, item.role)}
                          disabled={actionLoading === item.id}
                          style={{ 
                            padding: '4px 8px', 
                            fontSize: '12px',
                            border: '1px solid #3b82f6', 
                            background: '#fff', 
                            color: '#3b82f6',
                            cursor: actionLoading === item.id ? 'not-allowed' : 'pointer'
                          }}
                        >
                          {actionLoading === item.id ? 'Loading...' : 'Change Role'}
                        </button>
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
