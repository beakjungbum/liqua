import { test, before, after, beforeEach, describe } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp,
  runTransaction,
} from 'firebase/firestore';

let env;
const ME = 'alice';
const OTHER = 'bob';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-liqua',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const me = () => env.authenticatedContext(ME).firestore();
const other = () => env.authenticatedContext(OTHER).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const seed = (path, data) =>
  env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), path), data));

const now = () => Timestamp.now();

const validAsset = () => ({
  name: 'Samsung', category: 'stock', quantity: 1.5, purchasePrice: 100,
  currentPrice: 120.5, memo: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
});
const validTx = () => ({
  amount: 5000, income: false, merchant: 'Cafe', category: 'food',
  at: now(), source: 'manual', confirmed: true,
});
const validFixed = () => ({ name: 'Rent', amount: 500000, day: 25, remind: true });
const validNotice = () => ({ raw: 'payment text', at: now(), app: 'bank' });
const validSnap = () => ({ total: 123456, at: now() });

const cols = {
  assets: [validAsset, { name: 'Renamed' }],
  transactions: [validTx, { amount: 7000 }],
  fixed: [validFixed, { day: 1 }],
  notices: [validNotice, { raw: 'x' }],
  snapshots: [validSnap, { total: 0 }],
};

describe('access control', () => {
  for (const [col, [mk]] of Object.entries(cols)) {
    const path = `users/${ME}/${col}/d1`;
    test(`${col}: owner can create/read/delete`, async () => {
      await assertSucceeds(setDoc(doc(me(), path), mk()));
      await assertSucceeds(getDoc(doc(me(), path)));
      await assertSucceeds(deleteDoc(doc(me(), path)));
    });
    test(`${col}: other user denied read/write/delete`, async () => {
      await seed(path, mk());
      await assertFails(getDoc(doc(other(), path)));
      await assertFails(setDoc(doc(other(), `users/${ME}/${col}/d2`), mk()));
      await assertFails(updateDoc(doc(other(), path), {}));
      await assertFails(deleteDoc(doc(other(), path)));
    });
    test(`${col}: unauthenticated denied`, async () => {
      await seed(path, mk());
      await assertFails(getDoc(doc(anon(), path)));
      await assertFails(setDoc(doc(anon(), `users/${ME}/${col}/d2`), mk()));
      await assertFails(deleteDoc(doc(anon(), path)));
    });
  }
  test('users profile: owner can delete own profile (account deletion)', async () => {
    await seed(`users/${ME}`, { uid: ME, targetAmount: 0 });
    await assertSucceeds(deleteDoc(doc(me(), `users/${ME}`)));
  });
  test('users profile: other and anon denied', async () => {
    await seed(`users/${ME}`, { uid: ME, targetAmount: 0 });
    await assertFails(getDoc(doc(other(), `users/${ME}`)));
    await assertFails(setDoc(doc(other(), `users/${ME}`), { targetAmount: 1 }, { merge: true }));
    await assertFails(deleteDoc(doc(other(), `users/${ME}`)));
    await assertFails(getDoc(doc(anon(), `users/${ME}`)));
    await assertFails(setDoc(doc(anon(), `users/${ME}`), { targetAmount: 1 }));
  });
  test('unknown paths denied', async () => {
    await assertFails(setDoc(doc(me(), `users/${ME}/other/x`), { a: 1 }));
    await assertFails(setDoc(doc(me(), `misc/x`), { a: 1 }));
    await assertFails(getDoc(doc(me(), `misc/x`)));
  });
});

describe('users/{uid}', () => {
  const p = `users/${ME}`;
  test('ensureUserDocument create (server timestamps)', async () => {
    await assertSucceeds(setDoc(doc(me(), p), {
      uid: ME, email: 'a@b.c', displayName: null, photoUrl: null,
      updatedAt: serverTimestamp(), createdAt: serverTimestamp(),
      targetAmount: 0, points: 0, currentLevel: 1,
    }));
  });
  test('ensureUserDocument update', async () => {
    await seed(p, { uid: ME, targetAmount: 5, points: 10, currentLevel: 1 });
    await assertSucceeds(updateDoc(doc(me(), p), {
      uid: ME, email: 'a@b.c', displayName: 'A', photoUrl: 'u', updatedAt: serverTimestamp(),
    }));
  });
  test('saveTargetAmount merge on missing doc', async () => {
    await assertSucceeds(setDoc(doc(me(), p), {
      targetAmount: 1000000, updatedAt: serverTimestamp(),
    }, { merge: true }));
  });
  test('awardPoints transaction set and update', async () => {
    const db = me();
    const ref = doc(db, p);
    await assertSucceeds(runTransaction(db, async (t) => {
      await t.get(ref);
      t.set(ref, {
        points: 10, currentLevel: 1, updatedAt: serverTimestamp(), uid: ME,
        targetAmount: 0, createdAt: serverTimestamp(),
      });
    }));
    await assertSucceeds(runTransaction(db, async (t) => {
      await t.get(ref);
      t.update(ref, { points: 20, currentLevel: 1, updatedAt: serverTimestamp() });
    }));
  });
  test('optional map/list/other fields allowed', async () => {
    await assertSucceeds(setDoc(doc(me(), p), {
      plan: { a: 1 }, profile: { b: 'x' }, growth: {}, celebrated: [1, 2],
      note: 'free', seenAt: now(),
    }, { merge: true }));
  });
  test('owner can delete', async () => {
    await seed(p, { uid: ME });
    await assertSucceeds(deleteDoc(doc(me(), p)));
  });
  const bad = {
    'targetAmount negative': { targetAmount: -1 },
    'targetAmount float': { targetAmount: 1.5 },
    'targetAmount string': { targetAmount: '5' },
    'points negative': { points: -1 },
    'points float': { points: 1.5 },
    'points string': { points: 'x' },
    'currentLevel string': { currentLevel: '1' },
    'currentLevel float': { currentLevel: 1.5 },
    'plan not map': { plan: 'x' },
    'profile not map': { profile: [1] },
    'growth not map': { growth: 3 },
    'celebrated not list': { celebrated: { a: 1 } },
  };
  for (const [name, data] of Object.entries(bad)) {
    test(`reject ${name} (create)`, async () => {
      await assertFails(setDoc(doc(me(), p), { uid: ME, ...data }));
    });
    test(`reject ${name} (merge update)`, async () => {
      await seed(p, { uid: ME, targetAmount: 0, points: 0, currentLevel: 1 });
      await assertFails(setDoc(doc(me(), p), data, { merge: true }));
    });
  }
});

describe('assets', () => {
  const p = `users/${ME}/assets/a1`;
  test('add: valid with null memo and server timestamps', async () => {
    await assertSucceeds(setDoc(doc(me(), p), validAsset()));
  });
  test('add: string memo, zero values, all categories', async () => {
    for (const c of ['stock', 'cash', 'deposit', 'etf', 'crypto', 'fx', 'other']) {
      await assertSucceeds(setDoc(doc(me(), `users/${ME}/assets/${c}`), {
        ...validAsset(), category: c, memo: 'hi', quantity: 0, purchasePrice: 0, currentPrice: 0,
      }));
    }
  });
  test('add inside transaction with points award', async () => {
    const db = me();
    const u = doc(db, `users/${ME}`);
    const a = doc(db, `users/${ME}/assets/a2`);
    await assertSucceeds(runTransaction(db, async (t) => {
      await t.get(u);
      t.set(a, validAsset());
      t.set(u, { points: 10, currentLevel: 1, updatedAt: serverTimestamp(), uid: ME,
        targetAmount: 0, createdAt: serverTimestamp() });
    }));
  });
  test('update (full field set) succeeds', async () => {
    await seed(p, { ...validAsset(), createdAt: now(), updatedAt: now() });
    await assertSucceeds(updateDoc(doc(me(), p), {
      name: ' New ', category: 'cash', quantity: 2, purchasePrice: 3, currentPrice: 4,
      memo: null, updatedAt: serverTimestamp(),
    }));
  });
  test('partial update keeping valid state succeeds', async () => {
    await seed(p, { ...validAsset(), createdAt: now(), updatedAt: now() });
    await assertSucceeds(updateDoc(doc(me(), p), { currentPrice: 99 }));
  });
  const bad = {
    'name empty': { name: '' },
    'name too long': { name: 'x'.repeat(101) },
    'name number': { name: 5 },
    'category unknown': { category: 'bond' },
    'category number': { category: 1 },
    'quantity negative': { quantity: -1 },
    'quantity string': { quantity: '1' },
    'purchasePrice negative': { purchasePrice: -0.5 },
    'purchasePrice string': { purchasePrice: 'a' },
    'currentPrice negative': { currentPrice: -1 },
    'currentPrice null': { currentPrice: null },
    'memo number': { memo: 5 },
  };
  for (const [name, data] of Object.entries(bad)) {
    test(`reject ${name} (create)`, async () => {
      await assertFails(setDoc(doc(me(), p), { ...validAsset(), ...data }));
    });
    test(`reject ${name} (update)`, async () => {
      await seed(p, { ...validAsset(), createdAt: now(), updatedAt: now() });
      await assertFails(updateDoc(doc(me(), p), data));
    });
  }
  test('name boundaries 1 and 100 ok', async () => {
    await assertSucceeds(setDoc(doc(me(), p), { ...validAsset(), name: 'x' }));
    await assertSucceeds(setDoc(doc(me(), p), { ...validAsset(), name: 'x'.repeat(100) }));
  });
  for (const k of ['name', 'category', 'quantity', 'purchasePrice', 'currentPrice']) {
    test(`reject missing ${k}`, async () => {
      const d = validAsset(); delete d[k];
      await assertFails(setDoc(doc(me(), p), d));
    });
  }
  test('owner delete', async () => {
    await seed(p, validAsset());
    await assertSucceeds(deleteDoc(doc(me(), p)));
  });
});

function suite(col, mk, ok, bad, required) {
  describe(col, () => {
    const p = `users/${ME}/${col}/x1`;
    test('valid create', async () => { await assertSucceeds(setDoc(doc(me(), p), mk())); });
    for (const [i, extra] of ok.entries()) {
      test(`valid variant ${i}`, async () => {
        await assertSucceeds(setDoc(doc(me(), p), { ...mk(), ...extra }));
      });
    }
    test('valid update', async () => {
      await seed(p, mk());
      const [k, v] = Object.entries(ok[0] ?? {})[0] ?? Object.entries(mk())[0];
      await assertSucceeds(updateDoc(doc(me(), p), { [k]: v }));
    });
    for (const [name, data] of Object.entries(bad)) {
      test(`reject ${name} (create)`, async () => {
        await assertFails(setDoc(doc(me(), p), { ...mk(), ...data }));
      });
      test(`reject ${name} (update)`, async () => {
        await seed(p, mk());
        await assertFails(updateDoc(doc(me(), p), data));
      });
    }
    for (const k of required) {
      test(`reject missing ${k}`, async () => {
        const d = mk(); delete d[k];
        await assertFails(setDoc(doc(me(), p), d));
      });
    }
  });
}

suite('transactions', validTx,
  [{ income: true }, { amount: 1 }, { merchant: 'x'.repeat(80) }, { merchant: 'x' }],
  {
    'amount zero': { amount: 0 }, 'amount negative': { amount: -5 },
    'amount float': { amount: 1.5 }, 'amount string': { amount: '5' },
    'income string': { income: 'true' }, 'income number': { income: 1 },
    'merchant empty': { merchant: '' }, 'merchant too long': { merchant: 'x'.repeat(81) },
    'merchant number': { merchant: 3 }, 'category number': { category: 3 },
    'at string': { at: '2026-01-01' }, 'at number': { at: 1700000000 },
    'source number': { source: 1 }, 'confirmed string': { confirmed: 'yes' },
  },
  ['amount', 'income', 'merchant', 'at']);

suite('fixed', validFixed,
  [{ day: 1 }, { day: 31 }, { name: 'x'.repeat(60) }, { remind: false }],
  {
    'name empty': { name: '' }, 'name too long': { name: 'x'.repeat(61) },
    'name number': { name: 1 },
    'amount zero': { amount: 0 }, 'amount negative': { amount: -1 },
    'amount float': { amount: 2.5 }, 'amount string': { amount: 'a' },
    'day zero': { day: 0 }, 'day 32': { day: 32 }, 'day float': { day: 1.5 },
    'day string': { day: '5' }, 'remind string': { remind: 'y' },
  },
  ['name', 'amount', 'day']);

suite('notices', validNotice,
  [{ raw: '' }, { raw: 'x'.repeat(2000) }, { app: 'kakao' }],
  {
    'raw too long': { raw: 'x'.repeat(2001) }, 'raw number': { raw: 5 },
    'at string': { at: 'now' }, 'app number': { app: 5 },
  },
  ['raw', 'at']);

suite('snapshots', validSnap,
  [{ total: -100 }, { total: 0 }],
  {
    'total float': { total: 1.5 }, 'total string': { total: '1' },
    'at string': { at: 'x' }, 'at number': { at: 5 },
  },
  ['total', 'at']);
