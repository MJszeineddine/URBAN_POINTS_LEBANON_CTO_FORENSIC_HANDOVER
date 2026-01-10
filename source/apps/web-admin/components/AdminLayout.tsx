import Link from 'next/link';
import { ReactNode } from 'react';
import { signOut } from 'firebase/auth';
import { auth } from '../lib/firebaseClient';

interface AdminLayoutProps {
  children: ReactNode;
  title?: string;
}

export const AdminLayout = ({ children, title }: AdminLayoutProps) => {
  const handleLogout = async () => {
    await signOut(auth);
  };

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#f7f7f7' }}>
      <aside
        style={{
          width: '220px',
          background: '#0f172a',
          color: '#fff',
          padding: '24px 16px',
          boxSizing: 'border-box'
        }}
      >
        <div style={{ fontWeight: 700, marginBottom: '24px' }}>Admin</div>
        <nav style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <Link style={{ color: '#fff' }} href="/admin/dashboard">Dashboard</Link>
          <Link style={{ color: '#fff' }} href="/admin/users">Users</Link>
          <Link style={{ color: '#fff' }} href="/admin/merchants">Merchants</Link>
          <Link style={{ color: '#fff' }} href="/admin/offers">Offers</Link>
          <Link style={{ color: '#fff' }} href="/admin/diagnostics">Diagnostics</Link>
        </nav>
      </aside>

      <main style={{ flex: 1, display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
        <header
          style={{
            height: '56px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 16px',
            background: '#fff',
            borderBottom: '1px solid #e5e7eb'
          }}
        >
          <div style={{ fontWeight: 600 }}>{title || 'Admin'}</div>
          <button
            onClick={handleLogout}
            style={{
              background: '#0f172a',
              color: '#fff',
              border: 'none',
              padding: '8px 12px',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            Logout
          </button>
        </header>

        <div style={{ padding: '16px', flex: 1 }}>{children}</div>
      </main>
    </div>
  );
};
