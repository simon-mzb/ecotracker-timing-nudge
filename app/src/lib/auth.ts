import { SignJWT, jwtVerify } from "jose";
import bcrypt from "bcryptjs";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";

const HOUSEHOLD_COOKIE = "household_session";
const ADMIN_COOKIE = "admin_session";
const SESSION_MAX_AGE_SECONDS = 60 * 60 * 24 * 90; // 90 days

function getSecret(): Uint8Array {
  const secret = process.env.SESSION_SECRET;
  if (!secret) {
    throw new Error("SESSION_SECRET environment variable is not set");
  }
  return new TextEncoder().encode(secret);
}

export async function hashPasscode(passcode: string): Promise<string> {
  return bcrypt.hash(passcode, 10);
}

export async function verifyPasscode(
  passcode: string,
  hash: string,
): Promise<boolean> {
  return bcrypt.compare(passcode, hash);
}

type HouseholdPayload = { role: "household"; householdId: string };
type AdminPayload = { role: "admin" };

async function signSession(
  payload: HouseholdPayload | AdminPayload,
): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(`${SESSION_MAX_AGE_SECONDS}s`)
    .sign(getSecret());
}

async function verifySessionToken<T>(token: string): Promise<T | null> {
  try {
    const { payload } = await jwtVerify(token, getSecret());
    return payload as T;
  } catch {
    return null;
  }
}

export async function createHouseholdSession(
  householdId: string,
): Promise<void> {
  const token = await signSession({ role: "household", householdId });
  const cookieStore = await cookies();
  cookieStore.set(HOUSEHOLD_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_MAX_AGE_SECONDS,
  });
}

export async function createAdminSession(): Promise<void> {
  const token = await signSession({ role: "admin" });
  const cookieStore = await cookies();
  cookieStore.set(ADMIN_COOKIE, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: SESSION_MAX_AGE_SECONDS,
  });
}

export async function clearHouseholdSession(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(HOUSEHOLD_COOKIE);
}

export async function clearAdminSession(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.delete(ADMIN_COOKIE);
}

export async function getHouseholdId(): Promise<string | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(HOUSEHOLD_COOKIE)?.value;
  if (!token) return null;
  const payload = await verifySessionToken<HouseholdPayload>(token);
  return payload?.role === "household" ? payload.householdId : null;
}

export async function isAdmin(): Promise<boolean> {
  const cookieStore = await cookies();
  const token = cookieStore.get(ADMIN_COOKIE)?.value;
  if (!token) return false;
  const payload = await verifySessionToken<AdminPayload>(token);
  return payload?.role === "admin";
}

export async function requireHouseholdId(): Promise<string> {
  const householdId = await getHouseholdId();
  if (!householdId) redirect("/login");
  return householdId;
}

export async function requireAdmin(): Promise<void> {
  const ok = await isAdmin();
  if (!ok) redirect("/admin/login");
}
