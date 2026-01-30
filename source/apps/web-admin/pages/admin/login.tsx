import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { signInWithEmailAndPassword, onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from '../../lib/firebaseClient';

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async user => {
      if (!user) return;
      const token = await user.getIdTokenResult(true);
      if (token.claims.role === 'admin') {
        router.replace('/admin/dashboard');
      } else {
        await signOut(auth);
      }
    });
    return () => unsub();
  }, [router]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const cred = await signInWithEmailAndPassword(auth, email.trim(), password);
      const token = await cred.user.getIdTokenResult(true);
      if (token.claims.role !== 'admin') {
        await signOut(auth);
        setError('Access denied. Admin role is required.');
        setLoading(false);
        return;
      }
      router.replace('/admin/dashboard');
    } catch (err: any) {
      console.error('Login failed', err);
      setError(err?.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', background: '#f7f7f7' }}>
      <form
        onSubmit={handleSubmit}
        style={{ background: '#fff', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 6px rgba(0,0,0,0.05)', minWidth: '320px' }}
      >
        <h1 style={{ marginBottom: '16px' }}>Admin Login</h1>
        <label style={{ display: 'block', marginBottom: '8px' }}>
          Email
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
            style={{ width: '100%', padding: '8px', marginTop: '4px', boxSizing: 'border-box' }}
          />
        </label>
        <label style={{ display: 'block', marginBottom: '12px' }}>
          Password
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
            style={{ width: '100%', padding: '8px', marginTop: '4px', boxSizing: 'border-box' }}
          />
        </label>
        {error && (
          <div style={{ color: '#b91c1c', marginBottom: '12px', fontSize: '14px' }}>
            {error}
          </div>
        )}
        <button
          type="submit"
          disabled={loading}
          style={{
            width: '100%',
            padding: '10px',
            background: '#0f172a',
            color: '#fff',
            border: 'none',
            borderRadius: '4px',
            cursor: loading ? 'not-allowed' : 'pointer'
          }}
        >
          {loading ? 'Signing in...' : 'Sign In'}
        </button>
      </form>
    </div>
  );
}
