import { useEffect, useState } from 'react';
import { collection, getDocs, limit, query, where, orderBy, QueryDocumentSnapshot, DocumentData } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { AdminGuard } from '../../components/AdminGuard';
import { AdminLayout } from '../../components/AdminLayout';
import { db, functions } from '../../lib/firebaseClient';

interface ManualPayment {
  id: string;
  user_id: string;
  service: 'WHISH' | 'OMT';
  amount: number;
  currency: string;
  receipt_number: string;
  status: 'pending' | 'approved' | 'rejected';
  submitted_at: any;
  agent_name?: string;
  agent_location?: string;
  approval_note?: string;
}

const PAGE_SIZE = 20;

export default function ManualPaymentsPage() {
  const [payments, setPayments] = useState<ManualPayment[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [selectedPayment, setSelectedPayment] = useState<ManualPayment | null>(null);
  const [selectedPlanId, setSelectedPlanId] = useState('');
  const [rejectionReason, setRejectionReason] = useState('');
  const [showApprovalModal, setShowApprovalModal] = useState(false);
  const [showRejectionModal, setShowRejectionModal] = useState(false);

  const fetchPendingPayments = async () => {
    setLoading(true);
    setError('');
    setSuccessMessage('');
    try {
      const getPending = httpsCallable(functions, 'getPendingManualPayments');
      const result = await getPending({}) as any;
      
      if (result.data.success) {
        setPayments(result.data.payments || []);
      } else {
        setError(result.data.error || 'Failed to load payments');
      }
    } catch (err: any) {
      console.error('Failed to load manual payments', err);
      setError(err?.message || 'Failed to load manual payments');
      setPayments([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPendingPayments();
  }, []);

  const handleApproveClick = (payment: ManualPayment) => {
    setSelectedPayment(payment);
    setSelectedPlanId('');
    setShowApprovalModal(true);
  };

  const handleApproveSubmit = async () => {
    if (!selectedPayment || !selectedPlanId) {
      setError('Please select a subscription plan');
      return;
    }

    setActionLoading(selectedPayment.id);
    setError('');
    setSuccessMessage('');

    try {
      const approvePayment = httpsCallable(functions, 'approveManualPayment');
      const result = await approvePayment({
        paymentId: selectedPayment.id,
        planId: selectedPlanId,
      }) as any;

      if (result.data.success) {
        setSuccessMessage(`Payment ${selectedPayment.receipt_number} approved. Subscription created: ${result.data.subscriptionId}`);
        setShowApprovalModal(false);
        setSelectedPayment(null);
        setSelectedPlanId('');
        await fetchPendingPayments();
      } else {
        setError(result.data.error || 'Failed to approve payment');
      }
    } catch (err: any) {
      console.error('Failed to approve payment', err);
      setError(err?.message || 'Failed to approve payment');
    } finally {
      setActionLoading(null);
    }
  };

  const handleRejectClick = (payment: ManualPayment) => {
    setSelectedPayment(payment);
    setRejectionReason('');
    setShowRejectionModal(true);
  };

  const handleRejectSubmit = async () => {
    if (!selectedPayment || !rejectionReason.trim()) {
      setError('Please provide a rejection reason');
      return;
    }

    setActionLoading(selectedPayment.id);
    setError('');
    setSuccessMessage('');

    try {
      const rejectPayment = httpsCallable(functions, 'rejectManualPayment');
      const result = await rejectPayment({
        paymentId: selectedPayment.id,
        reason: rejectionReason,
      }) as any;

      if (result.data.success) {
        setSuccessMessage(`Payment ${selectedPayment.receipt_number} rejected`);
        setShowRejectionModal(false);
        setSelectedPayment(null);
        setRejectionReason('');
        await fetchPendingPayments();
      } else {
        setError(result.data.error || 'Failed to reject payment');
      }
    } catch (err: any) {
      console.error('Failed to reject payment', err);
      setError(err?.message || 'Failed to reject payment');
    } finally {
      setActionLoading(null);
    }
  };

  const formatCurrency = (amount: number, currency: string) => {
    if (currency === 'LBP') {
      return `${amount.toLocaleString()} LBP`;
    }
    return `$${amount.toFixed(2)} ${currency}`;
  };

  const formatDate = (timestamp: any) => {
    if (!timestamp) return 'N/A';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  return (
    <AdminGuard>
      <AdminLayout>
        <div className="p-6 bg-white rounded-lg shadow">
          <div className="mb-6">
            <h1 className="text-3xl font-bold text-gray-900">Manual Payment Verification</h1>
            <p className="text-gray-600 mt-2">Review and approve Whish/OMT payment receipts</p>
          </div>

          {error && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 text-red-800 rounded">
              {error}
            </div>
          )}

          {successMessage && (
            <div className="mb-4 p-4 bg-green-50 border border-green-200 text-green-800 rounded">
              {successMessage}
            </div>
          )}

          <div className="mb-4">
            <button
              onClick={fetchPendingPayments}
              disabled={loading}
              className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:bg-gray-400"
            >
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>

          {loading && (
            <div className="text-center py-8 text-gray-500">Loading pending payments...</div>
          )}

          {!loading && payments.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              No pending manual payments to review
            </div>
          )}

          {!loading && payments.length > 0 && (
            <div className="overflow-x-auto">
              <table className="w-full border-collapse">
                <thead className="bg-gray-100 border-b">
                  <tr>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Receipt #</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Service</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Amount</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Submitted</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Agent Info</th>
                    <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {payments.map((payment) => (
                    <tr key={payment.id} className="border-b hover:bg-gray-50">
                      <td className="px-4 py-3 text-sm font-mono text-gray-900">{payment.receipt_number}</td>
                      <td className="px-4 py-3 text-sm">
                        <span className={`px-2 py-1 rounded text-white text-xs font-semibold ${
                          payment.service === 'WHISH' ? 'bg-blue-600' : 'bg-purple-600'
                        }`}>
                          {payment.service}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm font-semibold text-gray-900">
                        {formatCurrency(payment.amount, payment.currency)}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600">
                        {formatDate(payment.submitted_at)}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600">
                        {payment.agent_name && <div>{payment.agent_name}</div>}
                        {payment.agent_location && <div className="text-xs text-gray-500">{payment.agent_location}</div>}
                        {!payment.agent_name && <span className="text-gray-400">-</span>}
                      </td>
                      <td className="px-4 py-3 text-sm space-x-2">
                        <button
                          onClick={() => handleApproveClick(payment)}
                          disabled={actionLoading === payment.id}
                          className="px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700 disabled:bg-gray-400 text-xs"
                        >
                          {actionLoading === payment.id ? 'Processing...' : 'Approve'}
                        </button>
                        <button
                          onClick={() => handleRejectClick(payment)}
                          disabled={actionLoading === payment.id}
                          className="px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 disabled:bg-gray-400 text-xs"
                        >
                          {actionLoading === payment.id ? 'Processing...' : 'Reject'}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* Approval Modal */}
        {showApprovalModal && selectedPayment && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
              <h2 className="text-xl font-bold mb-4">Approve Payment</h2>
              <p className="text-gray-700 mb-4">
                Receipt: <span className="font-mono font-semibold">{selectedPayment.receipt_number}</span>
                <br />
                Amount: <span className="font-semibold">{formatCurrency(selectedPayment.amount, selectedPayment.currency)}</span>
              </p>
              
              <div className="mb-4">
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Select Subscription Plan
                </label>
                <select
                  value={selectedPlanId}
                  onChange={(e) => setSelectedPlanId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:border-blue-500"
                >
                  <option value="">-- Select Plan --</option>
                  <option value="customer_basic">Customer Basic ($8/month)</option>
                  <option value="customer_premium">Customer Premium ($15/month)</option>
                  <option value="merchant_pro">Merchant Pro ($20/month)</option>
                  <option value="merchant_elite">Merchant Elite ($50/month)</option>
                </select>
              </div>

              {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

              <div className="flex gap-3">
                <button
                  onClick={() => {
                    setShowApprovalModal(false);
                    setSelectedPayment(null);
                    setError('');
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleApproveSubmit}
                  disabled={actionLoading !== null || !selectedPlanId}
                  className="flex-1 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 disabled:bg-gray-400"
                >
                  {actionLoading ? 'Processing...' : 'Confirm Approval'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Rejection Modal */}
        {showRejectionModal && selectedPayment && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
              <h2 className="text-xl font-bold mb-4">Reject Payment</h2>
              <p className="text-gray-700 mb-4">
                Receipt: <span className="font-mono font-semibold">{selectedPayment.receipt_number}</span>
              </p>
              
              <div className="mb-4">
                <label className="block text-sm font-semibold text-gray-700 mb-2">
                  Rejection Reason
                </label>
                <textarea
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="Enter reason for rejection..."
                  className="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:border-red-500"
                  rows={4}
                />
              </div>

              {error && <p className="text-red-600 text-sm mb-4">{error}</p>}

              <div className="flex gap-3">
                <button
                  onClick={() => {
                    setShowRejectionModal(false);
                    setSelectedPayment(null);
                    setError('');
                    setRejectionReason('');
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleRejectSubmit}
                  disabled={actionLoading !== null || !rejectionReason.trim()}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 disabled:bg-gray-400"
                >
                  {actionLoading ? 'Processing...' : 'Confirm Rejection'}
                </button>
              </div>
            </div>
          </div>
        )}
      </AdminLayout>
    </AdminGuard>
  );
}
