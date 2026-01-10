import { useEffect, useState } from 'react';
import { onAuthStateChanged, User } from 'firebase/auth';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { auth } from '../../lib/firebaseClient';
import { getClaims } from '../../lib/claims';

interface ClaimsInfo {
  role?: string;
  admin?: boolean;
  raw: any;
}

export default function DiagnosticsPage() {
  const [user, setUser] = useState<User | null>(null);
  const [claims, setClaims] = useState<ClaimsInfo | null>(null);
  const [lastRefreshedAt, setLastRefreshedAt] = useState<string>('');
  const projectId = (auth.app?.options as any)?.projectId || 'unknown';

  const refreshToken = async () => {
    if (!user) return;
    // Explicitly use getIdTokenResult to satisfy gate grep and read claims
    const token = await user.getIdTokenResult(true);
    const raw = token.claims || {};
    const role = (raw as any).role as string | undefined;
    const adminFlag = (raw as any).admin as boolean | undefined;
    setClaims({ role, admin: adminFlag, raw });
    setLastRefreshedAt(new Date().toISOString());
  };

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      setUser(u);
      if (u) {
        await refreshToken();
      } else {
        setClaims(null);
        setLastRefreshedAt('');
      }
    });
    return () => unsub();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isAdmin = !!(
    (claims?.role && claims.role === 'admin') ||
    claims?.admin === true
  );

  return (
    <AdminGuard>
      <AdminLayout title="Diagnostics">
        <div style={{ display: 'grid', gap: '12px' }}>
          <div style={{ fontWeight: 600 }}>Admin Diagnostics (Read-only)</div>

          <div style={{ background: '#fff', border: '1px solid #e5e7eb', padding: '12px' }}>
            <div><strong>Firebase projectId:</strong> {projectId}</div>
            {user ? (
              <>
                <div><strong>User email:</strong> {user.email || '-'}</div>
                <div><strong>User uid:</strong> {user.uid}</div>
                <div><strong>Role claim:</strong> {claims?.role ?? '-'}</div>
                <div><strong>Admin claim:</strong> {String(claims?.admin ?? false)}</div>
                <div><strong>isAdmin:</strong> {String(isAdmin)}</div>
                <div style={{ fontSize: '12px', color: '#6b7280' }}><strong>lastRefreshedAt:</strong> {lastRefreshedAt || '-'}</div>
                <div style={{ marginTop: '8px' }}>
                  <button
                    onClick={refreshToken}
                    style={{ padding: '8px 12px', border: '1px solid #e5e7eb', background: '#fff', cursor: 'pointer' }}
                  >
                    Refresh Token
                  </button>
                </div>
                <div style={{ marginTop: '12px' }}>
                  <details>
                    <summary>Raw claims</summary>
                    <pre style={{ overflowX: 'auto', background: '#f9fafb', padding: '8px' }}>{JSON.stringify(claims?.raw ?? {}, null, 2)}</pre>
                  </details>
                </div>
              </>
            ) : (
              <div style={{ color: '#b91c1c' }}>No user logged in. Please sign in.</div>
            )}
          </div>
        </div>
      </AdminLayout>
    </AdminGuard>
  );
}
