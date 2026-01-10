import { ReactNode, useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { onAuthStateChanged, signOut, User } from 'firebase/auth';
import { auth } from '../lib/firebaseClient';

interface AdminGuardProps {
  children: ReactNode;
}

export const AdminGuard = ({ children }: AdminGuardProps) => {
  const router = useRouter();
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user: User | null) => {
      if (!user) {
        setChecking(false);
        router.replace('/admin/login');
        return;
      }

      try {
        const token = await user.getIdTokenResult(true);
        if (token.claims.role !== 'admin') {
          await signOut(auth);
          setChecking(false);
          router.replace('/admin/login');
          return;
        }
        setChecking(false);
      } catch (err) {
        console.error('Admin guard failed', err);
        await signOut(auth);
        setChecking(false);
        router.replace('/admin/login');
      }
    });

    return () => unsubscribe();
  }, [router]);

  if (checking) {
    return (
      <div style={{ padding: '24px', fontSize: '16px' }}>
        Checking admin access...
      </div>
    );
  }

  return <>{children}</>;
};
