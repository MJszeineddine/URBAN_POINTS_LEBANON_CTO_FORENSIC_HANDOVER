import { User } from 'firebase/auth';

export async function getClaims(user: User | null): Promise<{ role?: string; admin?: boolean; raw: any } | null> {
  if (!user) return null;
  const token = await user.getIdTokenResult(true);
  const claims = token.claims || {} as any;
  return {
    role: (claims as any).role as string | undefined,
    admin: (claims as any).admin as boolean | undefined,
    raw: claims
  };
}
