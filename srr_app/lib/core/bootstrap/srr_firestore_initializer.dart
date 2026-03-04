// ---------------------------------------------------------------------------
// srr_app/lib/core/bootstrap/srr_firestore_initializer.dart
// ---------------------------------------------------------------------------
//
// Purpose:
// - Creates the Firestore client against the configured database ID.
// Architecture:
// - Bootstrap infrastructure component that enforces explicit Firestore database
//   selection, avoiding accidental use of the default database.
// Author: Neil Khatu
// Copyright (c) The Khatu Family Trust
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../src/config/srr_runtime_env.dart';

class SrrFirestoreInitializer {
  const SrrFirestoreInitializer();

  FirebaseFirestore initialize() {
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: SrrRuntimeEnv.firestoreDatabaseId,
    );
  }
}
