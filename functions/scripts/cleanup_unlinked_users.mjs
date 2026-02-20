#!/usr/bin/env node

// ---------------------------------------------------------------------------
// functions/scripts/cleanup_unlinked_users.mjs
// ---------------------------------------------------------------------------
//
// Purpose:
// - Removes stale user/player/email documents that are not referenced by any
//   firebase identity record.
// Architecture:
// - Node script using firebase-admin directly for on-demand cleanup.
// - Safe to run from local dev or CI once the Firebase project is configured.
// Author: The Khatu Family Trust
// Copyright (c) The Khatu Family Trust
//
import admin from 'firebase-admin';

const FIREBASE_COLLECTIONS = {
  users: 'users',
  players: 'players',
  userEmails: 'user_emails',
  firebaseIdentities: 'firebase_identities',
};

function numericValue(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.trunc(parsed);
    }
  }
  return 0;
}

function ensureInitialized() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
}

async function fetchLinkedUserIds(db) {
  const snapshot = await db.collection(FIREBASE_COLLECTIONS.firebaseIdentities).get();
  const userIds = new Set();
  snapshot.docs.forEach((doc) => {
    const id = numericValue(doc.data()?.user_id);
    if (id > 0) {
      userIds.add(id);
    }
  });
  return userIds;
}

async function pruneCollection({db, collection, userIdField, linkedIds}) {
  const snapshot = await db.collection(collection).get();
  const toDelete = [];
  snapshot.docs.forEach((doc) => {
    const candidate = numericValue(doc.data()?.[userIdField] ?? doc.data()?.id ?? doc.id);
    if (!linkedIds.has(candidate)) {
      toDelete.push(doc.ref);
    }
  });
  if (toDelete.length === 0) {
    console.log(`0 documents removed from ${collection}.`);
    return;
  }
  console.log(`Deleting ${toDelete.length} documents from ${collection}...`);
  for (const ref of toDelete) {
    await ref.delete();
  }
  console.log(`Pruned ${collection}.`);
}

async function main() {
  ensureInitialized();
  const db = admin.firestore();
  const linkedIds = await fetchLinkedUserIds(db);
  if (linkedIds.size === 0) {
    console.log('No firebase identity records found. Skipping cleanup.');
    return;
  }
  await pruneCollection({
    db,
    collection: FIREBASE_COLLECTIONS.users,
    userIdField: 'id',
    linkedIds,
  });
  await pruneCollection({
    db,
    collection: FIREBASE_COLLECTIONS.players,
    userIdField: 'user_id',
    linkedIds,
  });
  await pruneCollection({
    db,
    collection: FIREBASE_COLLECTIONS.userEmails,
    userIdField: 'user_id',
    linkedIds,
  });
  console.log('Cleanup complete.');
}

main().catch((error) => {
  console.error('Cleanup failed:', error);
  process.exit(1);
});
