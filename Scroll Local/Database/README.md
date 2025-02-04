# Firebase Database Migrations

This directory contains database migration scripts for the Scroll Local app. These scripts help maintain consistent database structure and security rules across different environments.

## Directory Structure

```
Database/
├── Migrations/
│   └── 001_initial_setup.js    # Initial database setup
├── apply_migrations.js         # Script to apply migrations
├── service-account-key.json    # Firebase Admin SDK credentials (not in git)
└── README.md                   # This file
```

## Setting Up

1. Install Node.js dependencies:
   ```bash
   npm install firebase-admin
   ```

2. Get your Firebase Admin SDK credentials:
   - Go to Firebase Console > Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save the file as `service-account-key.json` in this directory
   - **IMPORTANT:** Do not commit this file to version control

## Running Migrations

1. Make sure you have your `service-account-key.json` in place
2. Run the migration script:
   ```bash
   node apply_migrations.js
   ```

## Creating New Migrations

1. Create a new file in the `Migrations` directory with the format:
   ```
   XXX_description.js
   ```
   where XXX is a sequential number (e.g., 002, 003)

2. Follow the structure in `001_initial_setup.js`:
   - Export collections schema
   - Export security rules
   - Export storage rules
   - Export indexes

## Manual Steps Required

After running migrations, some steps need to be done manually in the Firebase Console:

1. Set up composite indexes
2. Verify security rules
3. Configure Authentication providers (Google Sign-in)
4. Set up Storage bucket if not already configured

## Security Notes

- Never commit `service-account-key.json` to version control
- Always review security rules before applying them
- Test migrations in a development environment first
- Back up your database before running migrations in production

## Current Collections

### Users
- Basic user profile information
- Following/Followers relationships
- Location data

### Videos
- Video metadata and content
- Geolocation support
- View/like/share counts
- Privacy settings

### Comments
- Video comments
- Like counts
- User attribution

## Indexes

The migrations will create necessary indexes for:
- Geospatial queries
- Time-based sorting
- Tag-based filtering
- User-specific queries

## Setup Instructions

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase in your project**:
   ```bash
   cd "Scroll Local"
   firebase init
   ```
   Select:
   - Firestore
   - Storage
   - When asked about rules files, use the existing ones

4. **Deploy the configuration**:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

This will:
- Set up all security rules
- Create all required indexes
- Configure storage rules

The collections themselves will be created automatically when data is first added. 