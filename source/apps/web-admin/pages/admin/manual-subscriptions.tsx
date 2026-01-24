import { useEffect, useState } from 'react';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { auth } from '../../lib/firebaseClient';

interface UserResult {
  id: string;
  phone: string;
  name?: string;
  is_active?: boolean;
}

interface SubscriptionStatus {
  hasActiveSubscription: boolean;
  status?: string;
  planCode?: string;
  startAt?: string;
  endAt?: string;
  source?: string;
  note?: string;
  activatedBy?: string;
}

export default function ManualSubscriptionsPage() {
  const [searchPhone, setSearchPhone] = useState('');
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState('');
  const [users, setUsers] = useState<UserResult[]>([]);

  const [selectedUserId, setSelectedUserId] = useState('');
  const [selectedUserPhone, setSelectedUserPhone] = useState('');
  const [subStatus, setSubStatus] = useState<SubscriptionStatus | null>(null);
  const [statusLoading, setStatusLoading] = useState(false);
  const [statusError, setStatusError] = useState('');

  const [activationLoading, setActivationLoading] = useState(false);
  const [activationError, setActivationError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [planCode, setPlanCode] = useState('basic');
  const [durationDays, setDurationDays] = useState('30');
  const [note, setNote] = useState('');

  const getAuthToken = async (): Promise<string> => {
    const user = auth.currentUser;
    if (!user) throw new Error('Not authenticated');
    return await user.getIdToken(true);
  };

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchPhone.trim()) {
      setSearchError('Please enter a phone number');
      return;
    }

    setSearchLoading(true);
    setSearchError('');
    setUsers([]);
    setSelectedUserId('');
    setSubStatus(null);

    try {
      const token = await getAuthToken();
      const res = await fetch(
        `/api/admin/users/search?phone=${encodeURIComponent(searchPhone)}`,
        { headers: { Authorization: `Bearer ${token}` } }
      );

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || `Search failed: ${res.statusText}`);
      }

      const data = await res.json();
      setUsers(data.data || []);
      if (data.data?.length === 0) {
        setSearchError('No users found matching that phone number');
      }
    } catch (err: any) {
      console.error('Search failed:', err);
      setSearchError(err?.message || 'Failed to search users');
    } finally {
      setSearchLoading(false);
    }
  };

  const handleSelectUser = async (userId: string, phone: string) => {
    setSelectedUserId(userId);
    setSelectedUserPhone(phone);
    setStatusLoading(true);
    setStatusError('');
    setSubStatus(null);
    setActivationError('');
    setSuccessMessage('');

    try {
      const token = await getAuthToken();
      const res = await fetch(`/api/admin/subscriptions/status?userId=${encodeURIComponent(userId)}`, {
        headers: { Authorization: `Bearer ${token}` }
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || `Status check failed: ${res.statusText}`);
      }

      const data = await res.json();
      setSubStatus(data.data || {});
    } catch (err: any) {
      console.error('Status check failed:', err);
      setStatusError(err?.message || 'Failed to check subscription status');
    } finally {
      setStatusLoading(false);
    }
  };

  const handleActivate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUserId) {
      setActivationError('Please select a user first');
      return;
    }

    const duration = parseInt(durationDays, 10);
    if (isNaN(duration) || duration <= 0) {
      setActivationError('Duration must be a positive number');
      return;
    }

    setActivationLoading(true);
    setActivationError('');
    setSuccessMessage('');

    try {
      const token = await getAuthToken();
      const res = await fetch('/api/admin/subscriptions/activate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`
        },
        body: JSON.stringify({
          userId: selectedUserId,
          planCode,
          durationDays: duration,
          note
        })
      });

      if (!res.ok) {
        const data = await res.json();
        throw new Error(data.error || `Activation failed: ${res.statusText}`);
      }

      const data = await res.json();
      setSuccessMessage(`Subscription activated for ${selectedUserPhone}: ${planCode} for ${duration} days`);
      
      // Refresh subscription status
      setTimeout(() => handleSelectUser(selectedUserId, selectedUserPhone), 1000);
      
      // Reset form
      setPlanCode('basic');
      setDurationDays('30');
      setNote('');
    } catch (err: any) {
      console.error('Activation failed:', err);
      setActivationError(err?.message || 'Failed to activate subscription');
    } finally {
      setActivationLoading(false);
    }
  };

  return (
    <AdminGuard>
      <AdminLayout title="Manual Subscription Activation">
        <div className="max-w-6xl mx-auto p-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Search Panel */}
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold mb-4">1. Search Users</h2>
              <form onSubmit={handleSearch} className="space-y-4">
                <input
                  type="text"
                  placeholder="Enter phone number (e.g., +961..."
                  value={searchPhone}
                  onChange={(e) => setSearchPhone(e.target.value)}
                  disabled={searchLoading}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <button
                  type="submit"
                  disabled={searchLoading}
                  className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
                >
                  {searchLoading ? 'Searching...' : 'Search'}
                </button>
              </form>

              {searchError && <div className="mt-4 p-3 bg-red-50 text-red-700 rounded-md text-sm">{searchError}</div>}

              {users.length > 0 && (
                <div className="mt-4">
                  <p className="text-sm text-gray-600 mb-2">Found {users.length} user(s):</p>
                  <div className="space-y-2">
                    {users.map((user) => (
                      <button
                        key={user.id}
                        onClick={() => handleSelectUser(user.id, user.phone)}
                        className={`w-full text-left p-3 rounded-md border-2 transition ${
                          selectedUserId === user.id
                            ? 'border-blue-500 bg-blue-50'
                            : 'border-gray-200 hover:border-gray-300 bg-white'
                        }`}
                      >
                        <div className="font-medium text-sm">{user.phone}</div>
                        {user.name && <div className="text-xs text-gray-500">{user.name}</div>}
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* Activation Panel */}
            <div className="bg-white rounded-lg shadow p-6">
              <h2 className="text-lg font-semibold mb-4">2. Activate Subscription</h2>

              {selectedUserId && (
                <>
                  <div className="mb-4 p-3 bg-blue-50 rounded-md">
                    <p className="text-sm text-gray-600">Selected: <span className="font-medium">{selectedUserPhone}</span></p>
                  </div>

                  {statusLoading && <p className="text-sm text-gray-500 mb-4">Loading subscription status...</p>}

                  {statusError && (
                    <div className="mb-4 p-3 bg-red-50 text-red-700 rounded-md text-sm">{statusError}</div>
                  )}

                  {subStatus && !statusLoading && (
                    <div className="mb-4 p-3 bg-gray-50 rounded-md border border-gray-200">
                      <p className="text-xs text-gray-600 mb-2 font-semibold">Current Status</p>
                      {subStatus.hasActiveSubscription ? (
                        <>
                          <p className="text-sm font-medium text-green-700">✓ Active Subscription</p>
                          <p className="text-xs text-gray-600 mt-1">Plan: {subStatus.planCode}</p>
                          <p className="text-xs text-gray-600">Expires: {new Date(subStatus.endAt || '').toLocaleDateString()}</p>
                          {subStatus.note && <p className="text-xs text-gray-600 mt-1">Note: {subStatus.note}</p>}
                        </>
                      ) : (
                        <p className="text-sm text-gray-700">No active subscription</p>
                      )}
                    </div>
                  )}

                  <form onSubmit={handleActivate} className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Plan Code</label>
                      <select
                        value={planCode}
                        onChange={(e) => setPlanCode(e.target.value)}
                        disabled={activationLoading}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      >
                        <option value="basic">Basic (1 voucher/month)</option>
                        <option value="premium">Premium (5 vouchers/month)</option>
                        <option value="pro">Pro (unlimited/month)</option>
                      </select>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Duration (days)</label>
                      <input
                        type="number"
                        min="1"
                        max="365"
                        value={durationDays}
                        onChange={(e) => setDurationDays(e.target.value)}
                        disabled={activationLoading}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Internal Note (optional)</label>
                      <textarea
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        disabled={activationLoading}
                        placeholder="e.g., 'Offline payment received' or 'Complimentary activation'"
                        rows={2}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 text-sm"
                      />
                    </div>

                    <button
                      type="submit"
                      disabled={activationLoading}
                      className="w-full px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"
                    >
                      {activationLoading ? 'Activating...' : 'Activate Subscription'}
                    </button>
                  </form>
                </>
              )}

              {!selectedUserId && (
                <p className="text-sm text-gray-500 text-center py-8">Select a user from the search results to activate their subscription</p>
              )}

              {activationError && (
                <div className="mt-4 p-3 bg-red-50 text-red-700 rounded-md text-sm">{activationError}</div>
              )}

              {successMessage && (
                <div className="mt-4 p-3 bg-green-50 text-green-700 rounded-md text-sm">{successMessage}</div>
              )}
            </div>
          </div>
        </div>
      </AdminLayout>
    </AdminGuard>
  );
}
