import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';

export default function DashboardPage() {
  return (
    <AdminGuard>
      <AdminLayout title="Dashboard">
        <div style={{ display: 'grid', gap: '12px' }}>
          <div style={{ fontWeight: 600 }}>Admin Dashboard (Read-only)</div>
          <div style={{ fontSize: '14px', color: '#374151' }}>
            Use the sidebar to view users, merchants, and offers. All data is read-only. Only admins with custom claim role=admin can access.
          </div>
        </div>
      </AdminLayout>
    </AdminGuard>
  );
}
