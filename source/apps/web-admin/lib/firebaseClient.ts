import { initializeApp, getApps, getApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getFunctions } from 'firebase/functions';

// Firebase config is public and matches the mobile apps (urbangenspark project)
const firebaseConfig = {
  apiKey: 'AIzaSyBQi-N9xW2DGLOc2Esrd-o1dCJOxWv8eZM',
  authDomain: 'urbangenspark.firebaseapp.com',
  projectId: 'urbangenspark',
  storageBucket: 'urbangenspark.appspot.com',
  messagingSenderId: '106033670760',
  appId: '1:106033670760:web:9813321b4a65bdabacc644'
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const functions = getFunctions(app, 'us-central1');
